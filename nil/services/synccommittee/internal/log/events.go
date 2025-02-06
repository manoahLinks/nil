package log

import (
	"github.com/NilFoundation/nil/nil/common/logging"
	"github.com/NilFoundation/nil/nil/services/synccommittee/internal/types"
	"github.com/rs/zerolog"
)

func NewTaskEvent(
	logger zerolog.Logger,
	level zerolog.Level,
	task *types.Task,
) *zerolog.Event {
	//nolint:zerologlint // 'must be dispatched by Msg or Send method' error is ignored
	return logger.WithLevel(level).
		Stringer(logging.FieldTaskId, task.Id).
		Stringer(logging.FieldShardId, task.ShardId).
		Stringer(logging.FieldBatchId, task.BatchId).
		Stringer(logging.FieldBlockHash, task.BlockHash).
		Stringer(logging.FieldBlockNumber, task.BlockNum).
		Stringer(logging.FieldTaskType, task.TaskType).
		Interface(logging.FieldTaskParentId, task.ParentTaskId)
}

func NewTaskResultEvent(
	logger zerolog.Logger,
	level zerolog.Level,
	result *types.TaskResult,
) *zerolog.Event {
	//nolint:zerologlint // 'must be dispatched by Msg or Send method' error is ignored
	event := logger.WithLevel(level).
		Stringer(logging.FieldTaskId, result.TaskId).
		Stringer(logging.FieldTaskExecutorId, result.Sender).
		Bool("isSuccess", result.IsSuccess())

	if result.IsSuccess() {
		return event
	}

	return event.
		Str("errorText", result.Error.ErrText).
		Stringer("errorType", result.Error.ErrType)
}
