package types

import (
	"encoding/hex"
	"fmt"

	"github.com/NilFoundation/nil/nil/common/hexutil"
)

type Signature []byte

func (s Signature) MarshalText() ([]byte, error) {
	return hexutil.Bytes(s[:]).MarshalText()
}

func (s *Signature) UnmarshalText(input []byte) error {
	var b hexutil.Bytes
	if err := b.UnmarshalText(input); err != nil {
		return err
	}

	*s = make(Signature, len(b))
	copy(*s, b[:])
	return nil
}

func (s Signature) Hex() string {
	enc := make([]byte, hex.EncodedLen(len(s[:]))+2)
	copy(enc, "0x")
	hex.Encode(enc[2:], s[:])
	return string(enc)
}

func (s Signature) String() string {
	return s.Hex()
}

type BlsSignature []byte

type BlsAggregateSignature struct {
	Sig  hexutil.Bytes `json:"sig" yaml:"sig" ssz-max:"64"`
	Mask hexutil.Bytes `json:"mask" yaml:"mask" ssz-max:"128"`
}

func (b BlsAggregateSignature) String() string {
	return fmt.Sprintf("BlsAggregateSignature{Sig: %x, Mask: %x}", b.Sig, b.Mask)
}

// Generating this manually because fastssz purely supports nested structures
//go:generate go run github.com/NilFoundation/fastssz/sszgen --path signature.go -include ../../common/hexutil/bytes.go --objs BlsAggregateSignature
