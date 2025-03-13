package ibft

import (
	"context"

	"github.com/NilFoundation/nil/nil/common/logging"
	"github.com/NilFoundation/nil/nil/go-ibft/core"
	"github.com/NilFoundation/nil/nil/go-ibft/messages/proto"
	"github.com/NilFoundation/nil/nil/internal/network"
	protobuf "google.golang.org/protobuf/proto"
)

type transport interface {
	Multicast(msg *proto.IbftMessage) error
}

type gossipTransport struct {
	ctx   context.Context
	topic *network.PubSub
	proto string
}

func (g *gossipTransport) Multicast(msg *proto.IbftMessage) error {
	data, err := protobuf.Marshal(msg)
	if err != nil {
		return err
	}
	return g.topic.Publish(g.ctx, g.proto, data)
}

func (i *backendIBFT) Multicast(msg *proto.IbftMessage) {
	if err := i.transport.Multicast(msg); err != nil {
		i.logger.Error().Err(err).Msg("Fail to gossip")
	}
	i.mh.IncSentMessages(i.transportCtx, msg.Type.String())
}

func (i *backendIBFT) getProto() string {
	return ibftProto + "/shard/" + i.shardId.String()
}

// setupTransport sets up the gossip transport protocol
func (i *backendIBFT) setupTransport(ctx context.Context) error {
	// Define a new topic
	topic := i.nm.PubSub()

	// Subscribe to the newly created topic
	protocol := i.getProto()
	sub, err := topic.Subscribe(protocol)
	if err != nil {
		return err
	}

	go func(ctx context.Context) {
		defer sub.Close()

		ch := sub.Start(ctx, false)
		for {
			select {
			case <-ctx.Done():
				return
			case data := <-ch:
				if data == nil {
					i.logger.Trace().
						Str(logging.FieldTopic, protocol).
						Msg("Received empty message")
					continue
				}

				if !i.isActiveValidator() {
					continue
				}

				msg := &proto.IbftMessage{}
				if err := protobuf.Unmarshal(data, msg); err != nil {
					i.logger.Error().
						Err(err).
						Str(logging.FieldTopic, protocol).
						Msg("Failed to unmarshal topic message")
					continue
				}
				var height, round uint64
				if view := msg.GetView(); view != nil {
					height = view.Height
					round = view.Round
				}

				i.messageLog.Log().
					Hex("addr", msg.From).
					Stringer(logging.FieldType, msg.Type).
					Str(logging.FieldTopic, protocol).
					Uint64(logging.FieldHeight, height).
					Uint64(logging.FieldRound, round).
					Msg("[message]")

				i.consensus.AddMessage(msg)
				i.mh.IncReceivedMessages(ctx, msg.Type.String())
			}
		}
	}(ctx)

	i.transport = &gossipTransport{
		ctx:   ctx,
		topic: topic,
		proto: i.getProto(),
	}

	return nil
}

type localTransport struct {
	consensus *core.IBFT
}

func (l *localTransport) Multicast(msg *proto.IbftMessage) error {
	l.consensus.AddMessage(msg)
	return nil
}

func (i *backendIBFT) setupLocalTransport() {
	i.transport = &localTransport{
		consensus: i.consensus,
	}
}
