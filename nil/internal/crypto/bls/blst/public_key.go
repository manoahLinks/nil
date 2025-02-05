package blst

import (
	"errors"
	"fmt"

	"github.com/NilFoundation/nil/nil/common"
	bls_common "github.com/NilFoundation/nil/nil/internal/crypto/bls/common"
)

// PublicKey used in the BLS signature scheme.
type PublicKey struct {
	p *blstPublicKey
}

func publicKeyFromBytes(pubKey []byte, cacheCopy bool) (bls_common.PublicKey, error) {
	if len(pubKey) != common.BLSPublicKeySize {
		return nil, fmt.Errorf("public key must be %d bytes", common.BLSPublicKeySize)
	}
	// Subgroup check NOT done when decompressing pubkey.
	p := new(blstPublicKey).Uncompress(pubKey)
	if p == nil {
		return nil, errors.New("could not unmarshal bytes into public key")
	}
	// Subgroup and infinity check
	if !p.KeyValidat() {
		return nil, errors.New("public key is not valid")
	}
	pubKeyObj := &PublicKey{p: p}
	return pubKeyObj, nil
}
