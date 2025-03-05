{ lib
, stdenv
, biome
, callPackage
, npmHooks
, nodejs
, nil
, solc
, enableTesting ? true
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
    (cd rollup-bridge-contracts; npm run build)
    #cd niljs
    #npm run build
  '';

  doCheck = enableTesting;

  checkPhase = ''
    export BIOME_BINARY=${biome}/bin/biome

    npm run lint
    npm run test:unit
    npm run test:integration --cache=false
    npm run test:examples
    npm run lint:types
    npm run lint:jsdoc

    echo "tests finished successfully"
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
