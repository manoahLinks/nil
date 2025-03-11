{ lib
, stdenv
, biome
, callPackage
, npmHooks
, nodejs
, nil
, pkgs
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
    pkgs.nodePackages.ts-node
    pkgs.nodePackages.typescript
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

  doCheck = enableTesting;
  checkPhase = ''
    source .env
    echo "Starting go-ethereum in background..."
    ${lib.getExe pkgs.go-ethereum} \
      --http.vhosts "'*,localhost,host.docker.internal'" \
      --http --http.api admin,debug,web3,eth,txpool,miner,net,dev,personal \
      --http.corsdomain "*" --http.addr "0.0.0.0" --nodiscover \
      --maxpeers 0 --mine --networkid 1337 \
      --dev --allow-insecure-unlock --rpc.allow-unprotected-txs --dev.gaslimit 200000000 &

    ts-node ./scripts/wallet/fund-wallet.ts

    geth_pid=$!

    echo "Waiting for go-ethereum to start..."
    sleep 10 # Give the node time to initialize

    echo "Deploying contracts..."
    npx hardhat deploy --network geth --tags NilContracts

    echo "Stopping go-ethereum..."
    kill $geth_pid
    wait $geth_pid || true
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
    cp .env $out/
  '';
}

