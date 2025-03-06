{ lib
, stdenv
, biome
, callPackage
, npmHooks
, nodejs
, nil
, solc
, dotenv-cli
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
  ];

  npmDeps = (callPackage ./npmdeps.nix { });

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    solc
  ];

  dontConfigure = true;

  preUnpack = ''
    echo "Setting UV_USE_IO_URING=0 to work around the io_uring kernel bug"
    export UV_USE_IO_URING=0
  '';

  buildPhase = ''
    cd rollup-bridge-contracts
    pwd
    cp .env.example .env

    export GETH_PRIVATE_KEY=002f28996b406c557ff579766af59ba66a3f103b8b90de6e9baad8ae211c0071
    export GETH_WALLET_ADDRESS=0xc8d5559BA22d11B0845215a781ff4bF3CCa0EF89

    npx dotenv -e .env -- npx replace-in-file 'GETH_PRIVATE_KEY=""' "GETH_PRIVATE_KEY=$GETH_PRIVATE_KEY" .env
    npx dotenv -e .env -- npx replace-in-file 'GETH_WALLET_ADDRESS=""' "GETH_WALLET_ADDRESS=$GETH_WALLET_ADDRESS" .env
    echo "start compiling"
    npx hardhat clean && npx hardhat compile
  '';

  installPhase = ''
    mkdir -p $out
    mkdir -p $out/dist
    cp -r package.json $out
    cp -r src $out
    cp -r dist/* $out/dist
    cp -r ./rollup-bridge-contracts/ $out/
  '';
}
