package kyber

import (
	kyber "go.dedis.ch/kyber/v3"
	"go.dedis.ch/kyber/v3/sign"
)

type (
	kyberPublicKey  = kyber.Point
	kyberPrivateKey = kyber.Scalar
	kyberMask       = sign.Mask
)
