package bls

import (
	"github.com/NilFoundation/nil/nil/internal/crypto/bls/kyber"
)

func PrivateKeyFromBytes(data []byte) (PrivateKey, error) {
	return kyber.PrivateKeyFromBytes(data)
}

func PublicKeyFromBytes(data []byte) (PublicKey, error) {
	return kyber.PublicKeyFromBytes(data)
}

func SignatureFromBytes(data []byte) (Signature, error) {
	return kyber.SignatureFromBytes(data)
}

func NewRandomKey() PrivateKey {
	return kyber.NewRandomKey()
}

func NewMask(publics []PublicKey) (Mask, error) {
	return kyber.NewMask(publics)
}

// Note: The order of signatures and their corresponding public keys in the mask must match.
func AggregateSignatures(signatures []Signature, mask Mask) (Signature, error) {
	return kyber.AggregateSignatures(signatures, mask)
}
