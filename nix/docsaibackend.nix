{ lib
, stdenv
, callPackage
, npmHooks
, nodejs
}:

stdenv.mkDerivation rec {
  name = "aibackend";
  pname = "docsaibackend";
  src = lib.sourceByRegex ./.. [
    "package.json"
    "package-lock.json"
    "^docs_ai_backend(/.*)?$"
  ];

  npmDeps = (callPackage ./npmdeps.nix { });

  NODE_PATH = "$npmDeps";

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    nodejs.python
  ];

  dontConfigure = true;

  preUnpack = ''
    echo "Setting UV_USE_IO_URING=0 to work around the io_uring kernel bug"
    export UV_USE_IO_URING=0
  '';

  buildPhase = ''
    patchShebangs docs_ai_backend/node_modules

    (cd docs_ai_backend; npm ci && npm run build)
  '';

  checkPhase = ''
  '';

  installPhase = ''
    mkdir -p $out
    mv docs_ai_backend/ $out/docs_ai_backend
  '';
}
