{ lib
, stdenv
, biome
, callPackage
, npmHooks
, nodejs
, nil
, enableTesting ? false
}:

stdenv.mkDerivation rec {
  name = "rollup-bridge-contracts";
  pname = "rollup-bridge-contracts";
  src = lib.sourceByRegex ./.. [
    "package.json"
    "package-lock.json"
    "^niljs(/.*)?$"
    "^rollup-bridge-contracts(/.*)?$"
    "biome.json"
    "^create-nil-hardhat-project(/.*)?$"
  ];

  npmDeps = (callPackage ./npmdeps.nix { });

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  soljson26 = builtins.fetchurl {
    url = "https://binaries.soliditylang.org/wasm/soljson-v0.8.26+commit.8a97fa7a.js";
    sha256 = "1mhww44ni55yfcyn4hjql2hwnvag40p78kac7jjw2g2jdwwyb1fv";
  };

  buildPhase = ''
    export NODE_ENV=production

    echo "Installing soljson"
    (cd create-nil-hardhat-project; bash install_soljson.sh ${soljson26})
    export BIOME_BINARY=${biome}/bin/biome

    cd rollup-bridge-contracts
    pwd
    cp .env.example .env

    echo "start compiling"
    npx hardhat clean && npx hardhat compile

    echo "Running npm dedupe to reduce node_modules size"
    npm dedupe

    echo "Pruning development dependencies"
    npm prune --production

    # Remove unnecessary files from node_modules
    find ./node_modules -type f \( -name "*.md" -o -name "*.ts" -o -name "*.map" -o -name "*.test.*" -o -name "*.spec.*" \) -delete
    find ./node_modules -type d -name "test" -o -name "tests" | xargs rm -rf
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
    cp .env $out/
  '';
}
