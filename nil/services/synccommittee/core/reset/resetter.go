package reset

import (
	"context"
	"fmt"

	"github.com/NilFoundation/nil/nil/common/logging"
	scTypes "github.com/NilFoundation/nil/nil/services/synccommittee/internal/types"
	"github.com/rs/zerolog"
)

type BatchResetter interface {
	// ResetProgressPartial resets Sync Committee's block processing progress
	// to a point preceding batch with the specified ID.
	ResetProgressPartial(ctx context.Context, firstBatchToPurge scTypes.BatchId) (purgedBatches []scTypes.BatchId, err error)

	// ResetProgressNotProved resets Sync Committee's progress for all not yet proven blocks.
	ResetProgressNotProved(ctx context.Context) error
}

type TaskCanceler interface {
	// CancelTasksByBatchId cancels all tasks associated with the given batch ID and returns the slice of cancelled tasks.
	CancelTasksByBatchId(ctx context.Context, batchId scTypes.BatchId) ([]scTypes.CancelledTask, error)

	// CancelAllTasks cancels all pending and active tasks.
	CancelAllTasks(ctx context.Context) error
}

func NewStateResetter(logger zerolog.Logger, batchResetter BatchResetter, taskCanceler TaskCanceler) *StateResetter {
	return &StateResetter{
		batchResetter: batchResetter,
		taskCanceler:  taskCanceler,
		logger:        logger,
	}
}

type StateResetter struct {
	batchResetter BatchResetter
	taskCanceler  TaskCanceler
	logger        zerolog.Logger
}

func (r *StateResetter) ResetProgressPartial(ctx context.Context, failedBatchId scTypes.BatchId) error {
	r.logger.Info().
		Stringer(logging.FieldBatchId, failedBatchId).
		Msg("Started partial progress reset")

	purgedBatchIds, err := r.batchResetter.ResetProgressPartial(ctx, failedBatchId)
	if err != nil {
		return err
	}

	for _, batchId := range purgedBatchIds {
		// Tasks associated with the failed batch should not be cancelled at this point,
		// they will be marked as failed later
		if batchId == failedBatchId {
			continue
		}

		cancelledTasks, err := r.taskCanceler.CancelTasksByBatchId(ctx, batchId)
		if err != nil {
			return fmt.Errorf("failed to cancel tasks for batch with id=%s: %w", batchId, err)
		}

		r.logger.Info().Stringer(logging.FieldBatchId, batchId).Msgf("Cancelled %d tasks for batch", len(cancelledTasks))
		// todo: push cancellation requests to executors
	}

	r.logger.Info().
		Stringer(logging.FieldBatchId, failedBatchId).
		Msg("Finished partial progress reset")

	return nil
}

func (r *StateResetter) ResetProgressNotProved(ctx context.Context) error {
	r.logger.Info().Msg("Started not proven progress reset")

	if err := r.batchResetter.ResetProgressNotProved(ctx); err != nil {
		return fmt.Errorf("failed to reset progress not proved blocks: %w", err)
	}

	if err := r.taskCanceler.CancelAllTasks(ctx); err != nil {
		return fmt.Errorf("failed to cancel all tasks: %w", err)
	}

	r.logger.Info().Msg("Finished not proven progress reset")
	return nil
}
