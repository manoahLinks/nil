package ibft

import (
	"fmt"

	"github.com/NilFoundation/nil/nil/common"
	"github.com/NilFoundation/nil/nil/common/check"
	"github.com/NilFoundation/nil/nil/internal/crypto/bls"
	"github.com/NilFoundation/nil/nil/internal/types"
)

type Signer struct {
	privateKey   bls.PrivateKey
	rawPublicKey []byte
}

func getHash(data []byte) []byte {
	return common.PoseidonHash(data).Bytes()
}

func NewSigner(privateKey bls.PrivateKey) *Signer {
	rawPublicKey, err := privateKey.PublicKey().Marshal()
	check.PanicIfErr(err)
	return &Signer{
		privateKey:   privateKey,
		rawPublicKey: rawPublicKey,
	}
}

func (s *Signer) SignHash(hash []byte) (types.BlsSignature, error) {
	sig, err := s.privateKey.Sign(hash)
	if err != nil {
		return nil, err
	}
	return sig.Marshal()
}

func (s *Signer) Sign(data []byte) (types.BlsSignature, error) {
	return s.SignHash(getHash(data))
}

func (s *Signer) Verify(data []byte, sig types.BlsSignature) error {
	signature, err := bls.SignatureFromBytes(sig)
	if err != nil {
		return err
	}
	return signature.Verify(s.privateKey.PublicKey(), getHash(data))
}

func (s *Signer) VerifyWithKeyHash(publicKey []byte, hash []byte, sig types.BlsSignature) error {
	pk, err := bls.PublicKeyFromBytes(publicKey)
	if err != nil {
		return fmt.Errorf("failed to parse public key: %w", err)
	}
	signature, err := bls.SignatureFromBytes(sig)
	if err != nil {
		return err
	}
	return signature.Verify(pk, hash)
}

func (s *Signer) VerifyWithKey(publicKey []byte, data []byte, sig types.BlsSignature) error {
	return s.VerifyWithKeyHash(publicKey, getHash(data), sig)
}

func (s *Signer) GetPublicKey() []byte {
	return s.rawPublicKey
}
