{ lib
, stdenv
}:
let
  inherit (lib) optional;
in
stdenv.mkDerivation {

  name = "l1-contracts";
  pname = "l1-contracts";

  src = lib.sourceByRegex ./.. [
    "^l1-contracts(/.*)?$"
  ];

  buildPhase = ''
    cp -r ./l1-contracts/ $out/
  '';

}
