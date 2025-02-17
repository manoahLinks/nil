package ibft

import (
	"bytes"

	"github.com/NilFoundation/nil/nil/common/logging"
	"github.com/NilFoundation/nil/nil/go-ibft/messages"
	protoIBFT "github.com/NilFoundation/nil/nil/go-ibft/messages/proto"
	"github.com/NilFoundation/nil/nil/internal/config"
)

func (i *backendIBFT) IsValidProposal(rawProposal []byte) bool {
	proposal, err := i.unmarshalProposal(rawProposal)
	if err != nil {
		return false
	}

	_, err = i.validator.VerifyProposal(i.ctx, proposal)
	return err == nil
}

func (i *backendIBFT) IsValidValidator(msg *protoIBFT.IbftMessage) bool {
	msgNoSig, err := msg.PayloadNoSig()
	if err != nil {
		return false
	}

	loggerCtx := i.logger.With().Hex(logging.FieldPublicKey, msg.From)
	if view := msg.GetView(); view != nil {
		loggerCtx = loggerCtx.
			Uint64(logging.FieldHeight, view.Height).
			Uint64(logging.FieldRound, view.Round)
	}
	logger := loggerCtx.Logger()

	// Here we use transportCtx because this method could be called from the transport goroutine
	validators, err := i.validatorsCache.getValidators(i.transportCtx, msg.View.Height)
	if err != nil {
		logger.Error().
			Err(err).
			Msg("Failed to get validators")
		return false
	}

	pubkeys, err := config.CreateValidatorsPublicKeyMap(validators)
	if err != nil {
		logger.Error().
			Err(err).
			Msg("Failed to get validators public keys")
		return false
	}

	_, ok := pubkeys.Find(config.Pubkey(msg.From))
	if !ok {
		logger.Error().
			Msg("public key not found in validators list")
		return false
	}

	if err := i.signer.VerifyWithKey(msg.From, msgNoSig, msg.Signature); err != nil {
		logger.Err(err).Msg("Failed to verify signature")
		return false
	}

	return true
}

func (i *backendIBFT) IsProposer(id []byte, height, round uint64) bool {
	proposer, err := i.calcProposer(height, round)
	if err != nil {
		i.logger.Error().
			Err(err).
			Uint64(logging.FieldHeight, height).
			Uint64(logging.FieldRound, round).
			Msg("Failed to calculate proposer")
		return false
	}
	return bytes.Equal(proposer.PublicKey[:], id)
}

func (i *backendIBFT) IsValidProposalHash(proposal *protoIBFT.Proposal, hash []byte) bool {
	prop, err := i.unmarshalProposal(proposal.RawProposal)
	if err != nil {
		return false
	}

	block, err := i.validator.VerifyProposal(i.ctx, prop)
	if err != nil {
		return false
	}

	blockHash := block.Hash(i.shardId)
	isValid := bytes.Equal(blockHash.Bytes(), hash)
	if !isValid {
		i.logger.Error().
			Stringer("expected", blockHash).
			Hex("got", hash).
			Uint64(logging.FieldRound, proposal.Round).
			Uint64(logging.FieldHeight, uint64(prop.PrevBlockId)+1).
			Msg("Invalid proposal hash")
	}
	return isValid
}

func (i *backendIBFT) IsValidCommittedSeal(
	proposalHash []byte,
	committedSeal *messages.CommittedSeal,
) bool {
	if err := i.signer.VerifyWithKeyHash(committedSeal.Signer, proposalHash, committedSeal.Signature); err != nil {
		i.logger.Error().
			Err(err).
			Hex(logging.FieldPublicKey, committedSeal.Signer).
			Hex(logging.FieldSignature, committedSeal.Signature).
			Hex(logging.FieldBlockHash, proposalHash).
			Msg("Failed to verify signature")
		return false
	}
	return true
}
