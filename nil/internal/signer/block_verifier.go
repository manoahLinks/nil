package signer

import (
	"context"
	"errors"
	"fmt"

	"github.com/NilFoundation/nil/nil/internal/config"
	"github.com/NilFoundation/nil/nil/internal/db"
	"github.com/NilFoundation/nil/nil/internal/types"
	"github.com/rs/zerolog"
)

var errBlockVerify = errors.New("failed to verify block")

type BlockVerifier struct {
	shardId types.ShardId
	db      db.DB
}

func NewBlockVerifier(shardId types.ShardId, db db.DB) *BlockVerifier {
	return &BlockVerifier{
		shardId: shardId,
		db:      db,
	}
}

func (b *BlockVerifier) VerifyBlock(ctx context.Context, block *types.Block, logger zerolog.Logger) error {
	validatorsList, err := config.GetValidatorListForShard(ctx, b.db, block.Id, b.shardId, logger)
	if err != nil {
		return fmt.Errorf("%w: failed to get validators set: %w", errBlockVerify, err)
	}

	pubkeys, err := config.CreateValidatorsPublicKeyMap(validatorsList)
	if err != nil {
		return fmt.Errorf("%w: failed to get validators public keys: %w", errBlockVerify, err)
	}

	if err := block.VerifySignature(pubkeys.Keys(), b.shardId); err != nil {
		return fmt.Errorf("%w: failed to verify signature: %w", errBlockVerify, err)
	}
	return nil
}
