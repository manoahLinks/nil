{ lib
, stdenv
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
    "^rollup-bridge-contracts(/.*)?$"
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
    echo "Installing soljson"
    (cd create-nil-hardhat-project; bash install_soljson.sh ${soljson26})

    cd rollup-bridge-contracts
    cp .env.example .env

    echo "start compiling"
    npx hardhat clean && npx hardhat compile
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

    mv ../package-lock.json .
    rm ../package.json
    rm -rf ../node_modules
    ls -l -a ../
    
    npm ci
    ts-node ./scripts/wallet/fund-wallet.ts

    geth_pid=$!

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
