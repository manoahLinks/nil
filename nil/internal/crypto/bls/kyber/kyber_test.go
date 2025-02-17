package kyber

import (
	"testing"

	"github.com/NilFoundation/nil/nil/internal/crypto/bls/common"
	"github.com/stretchr/testify/require"
)

func TestAggregateSignatures(t *testing.T) {
	t.Parallel()

	msg := []byte("Hello Boneh-Lynn-Shacham")
	private1 := NewRandomKey()
	public1 := private1.PublicKey()
	private2 := NewRandomKey()
	public2 := private2.PublicKey()
	sig1, err := private1.Sign(msg)
	require.NoError(t, err)
	sig2, err := private2.Sign(msg)
	require.NoError(t, err)

	mask, err := NewMask([]common.PublicKey{public1, public2})
	require.NoError(t, err)
	require.NoError(t, mask.SetParticipants([]uint32{0, 1}))

	_, err = AggregateSignatures([]common.Signature{sig1}, mask)
	require.ErrorContains(t, err, "length of signatures and public keys must match")

	aggregatedSig, err := AggregateSignatures([]common.Signature{sig1, sig2}, mask)
	require.NoError(t, err)

	aggregatedKey, err := mask.AggregatePublicKeys()
	require.NoError(t, err)

	err = aggregatedSig.Verify(aggregatedKey, msg)
	require.NoError(t, err)

	require.NoError(t, mask.SetParticipants([]uint32{0}))
	aggregatedKey, err = mask.AggregatePublicKeys()
	require.NoError(t, err)

	err = aggregatedSig.Verify(aggregatedKey, msg)
	require.ErrorContains(t, err, "bls: invalid signature")
}

func TestSubsetSignature(t *testing.T) {
	t.Parallel()

	msg := []byte("Hello Boneh-Lynn-Shacham")
	private1 := NewRandomKey()
	public1 := private1.PublicKey()
	private2 := NewRandomKey()
	public2 := private2.PublicKey()
	_private3 := NewRandomKey()
	public3 := _private3.PublicKey()
	sig1, err := private1.Sign(msg)
	require.NoError(t, err)
	sig2, err := private2.Sign(msg)
	require.NoError(t, err)

	mask, err := NewMask([]common.PublicKey{public1, public3, public2})
	require.NoError(t, err)
	require.NoError(t, mask.SetParticipants([]uint32{0, 2}))

	aggregatedSig, err := AggregateSignatures([]common.Signature{sig1, sig2}, mask)
	require.NoError(t, err)

	aggregatedKey, err := mask.AggregatePublicKeys()
	require.NoError(t, err)

	err = aggregatedSig.Verify(aggregatedKey, msg)
	require.NoError(t, err)
}

func TestMarshal(t *testing.T) {
	t.Parallel()

	msg := []byte("Hello Boneh-Lynn-Shacham")
	private1 := NewRandomKey()
	marshaledPrivate, err := private1.Marshal()
	require.NoError(t, err)

	private2, err := PrivateKeyFromBytes(marshaledPrivate)
	require.NoError(t, err)
	require.Equal(t, private1, private2)

	sig1, err := private1.Sign(msg)
	require.NoError(t, err)

	marshaledSig, err := sig1.Marshal()
	require.NoError(t, err)

	sig2, err := SignatureFromBytes(marshaledSig)
	require.NoError(t, err)

	require.Equal(t, sig1, sig2)

	public1 := private1.PublicKey()
	marshaledPublic, err := public1.Marshal()
	require.NoError(t, err)

	public2, err := PublicKeyFromBytes(marshaledPublic)
	require.NoError(t, err)

	require.True(t, public1.Equal(public2))
}
