{ lib
, stdenv
, biome
, callPackage
, npmHooks
, nodejs
, nil
, solc
, enableTesting ? false
}:

stdenv.mkDerivation rec {
  name = "rollup-bridge-contracts";
  pname = "rollup-bridge-contracts";
  src = lib.sourceByRegex ./.. [ "package.json" "package-lock.json" "^niljs(/.*)?$" "^rollup-bridge-contracts(/.*)?$" "biome.json" ];

  npmDeps = (callPackage ./npmdeps.nix { });

  NODE_PATH = "$npmDeps";

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    biome
    solc
  ] ++ (if enableTesting then [ nil ] else [ ]);

  dontConfigure = true;

  preUnpack = ''
    echo "Setting UV_USE_IO_URING=0 to work around the io_uring kernel bug"
    export UV_USE_IO_URING=0
  '';

  buildPhase = ''
    cd rollup-bridge-contracts
    pwd
    echo 'GETH_RPC_ENDPOINT="http://localhost:8545"' >> .env
    echo 'GETH_PRIVATE_KEY="002f28996b406c557ff579766af59ba66a3f103b8b90de6e9baad8ae211c0071"' >> .env
    echo 'GETH_WALLET_ADDRESS="0xc8d5559BA22d11B0845215a781ff4bF3CCa0EF89"' >> .env

    npx hardhat clean
    npx hardhat compile
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
