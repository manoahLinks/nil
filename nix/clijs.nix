{ pkgs
, lib
, stdenv
, biome
, callPackage
, pnpm_10
, nil
, enableTesting ? false
}:

let
  sigtool = callPackage ./sigtool.nix { };
in
stdenv.mkDerivation rec {
  name = "clijs";
  pname = "clijs";
  src = lib.sourceByRegex ./.. [
    "package.json"
    "pnpm-lock.yaml"
    "pnpm-workspace.yaml"
    ".npmrc"
    "^clijs(/.*)?$"
    "^niljs(/.*)?$"
    "^smart-contracts(/.*)?$"
    "biome.json"
  ];

  pnpmDeps = (callPackage ./npmdeps.nix { });

  nativeBuildInputs = [
    pkgs.pkgsStatic.nodejs_22
    pnpm_10.configHook
    pnpm_10
    biome
  ]
  ++ lib.optionals stdenv.buildPlatform.isDarwin [ sigtool ]
  ++ (if enableTesting then [ nil ] else [ ]);

  preUnpack = ''
    echo "Setting UV_USE_IO_URING=0 to work around the io_uring kernel bug"
    export UV_USE_IO_URING=0
  '';

  postUnpack = ''
    mkdir source/nil
    cp -R ${nil}/contracts source/nil
  '';

  buildPhase = ''
    PATH="${pkgs.pkgsStatic.nodejs_22}/bin/:$PATH"

    (cd smart-contracts; pnpm run build)
    (cd niljs; pnpm run build)

    cd clijs
    pnpm run bundle
  '';

  doCheck = enableTesting;

  checkPhase = ''
    export BIOME_BINARY=${biome}/bin/biome

    npm run lint

    ./dist/clijs | grep -q "The CLI tool for interacting with the =nil; cluster" || {
      echo "Error: Output does not contain the expected substring!" >&2
      exit 1
    }
    echo "smoke check passed"

    nohup nild run --http-port 8529 --collator-tick-ms=100 > nild.log 2>&1 & echo $! > nild_pid &

    pnpm run test:ci

    kill `cat nild_pid` && rm nild_pid

    echo "tests finished successfully"
  '';

  installPhase = ''
    mkdir -p $out
    mv ./dist/clijs $out/${pname}
  '';
}

