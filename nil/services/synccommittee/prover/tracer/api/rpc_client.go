package api

import (
	"context"

	"github.com/NilFoundation/nil/nil/internal/types"
	"github.com/NilFoundation/nil/nil/services/rpc/jsonrpc"
)

type RpcClient interface {
	GetBlock(ctx context.Context, shardId types.ShardId, blockId any, fullTx bool) (*jsonrpc.RPCBlock, error)

	GetDebugBlock(ctx context.Context, shardId types.ShardId, blockId any, fullTx bool) (*jsonrpc.DebugRPCBlock, error)

	GetDebugContract(ctx context.Context, contractAddr types.Address, blockId any) (*jsonrpc.DebugRPCContract, error)
}
