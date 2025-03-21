{ lib
, stdenv
, biome
, callPackage
, pnpm_10
, nodejs
, nil
, enableTesting ? false
}:

stdenv.mkDerivation rec {
  name = "rollup-bridge-contracts";
  pname = "rollup-bridge-contracts";
  src = lib.sourceByRegex ./.. [
    "package.json"
    "pnpm-lock.yaml"
    "pnpm-workspace.yaml"
    ".npmrc"
    "^niljs(/.*)?$"
    "^rollup-bridge-contracts(/.*)?$"
    "biome.json"
    "^create-nil-hardhat-project(/.*)?$"
  ];

  pnpmDeps = (callPackage ./npmdeps.nix { });

  nativeBuildInputs = [
    nodejs
    pnpm_10.configHook
    pnpm_10
  ];

  soljson26 = builtins.fetchurl {
    url = "https://binaries.soliditylang.org/wasm/soljson-v0.8.26+commit.8a97fa7a.js";
    sha256 = "1mhww44ni55yfcyn4hjql2hwnvag40p78kac7jjw2g2jdwwyb1fv";
  };

  buildPhase = ''
    echo "Installing soljson"
    (cd create-nil-hardhat-project; bash install_soljson.sh ${soljson26})
    export BIOME_BINARY=${biome}/bin/biome

    cd rollup-bridge-contracts
    pwd
    cp .env.example .env

    echo "start compiling"
    npx hardhat clean && npx hardhat compile
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
    cp .env $out/
  '';
}
