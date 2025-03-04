{ lib
, stdenv
}:
let
  inherit (lib) optional;
in
stdenv.mkDerivation {

  name = "rollup-bridge-contracts";
  pname = "rollup-bridge-contracts";

  src = lib.sourceByRegex ./.. [
    "^rollup-bridge-contracts(/.*)?$"
  ];

  buildPhase = ''
    cp -r ./rollup-bridge-contracts/ $out/
  '';

}
