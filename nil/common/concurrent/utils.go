package concurrent

import (
	"context"
	"fmt"
	"runtime/debug"
	"sync"
	"time"
)

type Func = func(context.Context) error

type FuncWithSource struct {
	Func
	Stack string
}

type ExecutionError struct {
	Err   error
	Stack string
}

var _ error = (*ExecutionError)(nil)

func (e *ExecutionError) Error() string {
	var location string
	if e.Stack != "" {
		location = "\n" + e.Stack
	} else {
		location = "<unknown location>"
	}
	return fmt.Sprintf("goroutine failed: %s. Function was created at: %s", e.Err.Error(), location)
}

func WithSource(f Func) FuncWithSource {
	return FuncWithSource{
		Func: f,
		Stack: func(stack []byte) string {
			// We could use an approach like in dd-trace-go
			// https://github.com/DataDog/dd-trace-go/blob/ba03925427c3ecd73ce2d64af50/ddtrace/tracer/span.go#L376-L407,
			// but it's easier to just remove unnecessary lines from the output.
			newlineCount := 0
			for i := range stack {
				if stack[i] == '\n' {
					newlineCount++
					if newlineCount == 5 {
						return string(stack[i+1:])
					}
				}
			}
			return ""
		}(debug.Stack()),
	}
}

// RunWithTimeout calls each given function in a separate goroutine and waits for them to finish.
// It logs a fatal message if an error occurred.
// If timeout is positive, it is added to the context. Otherwise, it is ignored.
// Note that RunWithTimeout does not forcefully terminate the goroutines;
// your functions should be able to handle context cancellation.
func RunWithTimeout(ctx context.Context, timeout time.Duration, fs ...FuncWithSource) error {
	var wg sync.WaitGroup

	var cancel context.CancelFunc
	if timeout > 0 {
		ctx, cancel = context.WithTimeout(ctx, timeout)
	} else {
		ctx, cancel = context.WithCancel(ctx)
	}
	defer cancel()

	var once sync.Once
	var originError error
	for _, f := range fs {
		wg.Add(1)

		go func(fn FuncWithSource) {
			defer wg.Done()
			if err := fn.Func(ctx); err != nil {
				once.Do(func() {
					originError = &ExecutionError{
						Err:   err,
						Stack: fn.Stack,
					}
					cancel()
				})
			}
		}(f) // to avoid loop-variable reuse in goroutines
	}

	wg.Wait()
	return originError
}

// Run calls RunWithTimeout without a timeout.
func Run(ctx context.Context, fs ...FuncWithSource) error {
	return RunWithTimeout(ctx, 0, fs...)
}

// RunTickerLoop runs a loop that executes a function at regular intervals
func RunTickerLoop(ctx context.Context, interval time.Duration, onTick func(context.Context)) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			onTick(ctx)
		case <-ctx.Done():
			return
		}
	}
}

func RunWithRetries[T any](ctx context.Context, interval time.Duration, retries int, f func() (T, error)) (T, error) {
	timer := time.NewTimer(interval)
	defer timer.Stop()

	var res T
	var err error
	for range retries {
		select {
		case <-ctx.Done():
			return res, nil
		case <-timer.C:
			res, err = f()
			if err == nil {
				return res, nil
			}
		}
	}

	return res, fmt.Errorf("failed to run function after %d retries, last error: %w", retries, err)
}
