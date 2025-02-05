package blst

import blst "github.com/supranational/blst/bindings/go"

// Internal types for blst.
type (
	blstPublicKey          = blst.P1Affine
	blstSignature          = blst.P2Affine
	blstAggregateSignature = blst.P2Aggregate
	blstAggregatePublicKey = blst.P1Aggregate
)
