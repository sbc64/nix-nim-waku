{
  sources ? import ./nix/sources.nix,
  enableRln ? false,
}: let
  nimOverlay = final: prev: {
    nim-unwrapped = prev.nim-unwrapped.overrideAttrs (old: rec {
      pname = "nim-unwrapped";
      version = "1.2.16";
      strictDeps = true;
      patches = [./nixbuild.patch ./NIM_CONFIG_DIR.patch];
      src = prev.fetchurl {
        url = "https://nim-lang.org/download/nim-${version}.tar.xz";
        sha256 = "Ycw6UoCUDkCFhD/v3hoeNwz8MUUUxPW6gSrNLUqaz2s=";
      };
    });
    installPhase = ''
      runHook preInstall
      install -Dt $out/bin bin/*
      ln -sf $out/nim/bin/nim $out/bin/nim
      ./install.sh $out
      runHook postInstall
    '';
  };

  pkgs = import sources.nixpkgs {
    overlays = [nimOverlay];
  };

  nimlibbacktrace = pkgs.stdenv.mkDerivation rec {
    version = "0.0.8";
    pname = "nim-libbacktrace";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo = "nim-libbacktrace";
      rev = "v${version}";
      sha256 = "CnmP46QyPsC8c/lChxpRzzITk1Ebi+V+B3mlD0W+G/c=";
    };
    buildPhase = ''
      make BUILD_CXX_LIB=0
    '';
    installPhase = ''
      mkdir -p $out
      cp -r install/usr/lib $out/lib
    '';
  };
  rln = pkgs.rustPlatform.buildRustPackage rec {
    pname = "rln";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "kilic";
      repo = "rln";
      rev = "master";
      sha256 = "q68uaBlsXPjHP65KqPen57yxsEoQNGWf8FmRlVTqWPU=";
    };
    cargoPatches = [./cargo-lock.patch];
    cargoSha256 = "iA9DkHZvvV1O4BsZ2HOL8ocRjEqRrrzfzbQTmrJ4msI=";
  };
  wakunode = pkgs.stdenv.mkDerivation rec {
    # make sure that the commit actually compiles before packaging with nix
    #version = "0.7"; # release 0.7 doesn't work
    version = "master";
    pname = "nim-waku";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo = "nim-waku";
      rev = "4421b8de0074574c3740b71a197b4f6eeb90c1c5"; #"v${version}";
      sha256 = "SuKjtUwe+ZFNH3anh7HY9VdJ1IQhs1uvdzHbDLZ00pA="; #pkgs.lib.fakeSha256;
    };
    nativeBuildInputs = with pkgs; [nim-unwrapped libnatpmp miniupnpc];
    buildInputs = with pkgs; [pcre];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath nativeBuildInputs}";
    compileArgs =
      [
        "--out:build/wakunode"
        "--debugger:native"
        "--d:chronicles_log_level=INFO"
        "--verbosity:0"
        "--hints:off"
        "-d:release"
      ]
      ++ pkgs.lib.optional enableRln "-d:rln";

    buildPhase = ''
      export HOME=$TMPDIR
      # To avoid building these libraries we just link them with what
      # already exists in nixpkgs but we use the paths that nim compiler expects
      # them to be
      ln -s ${pkgs.libnatpmp}/lib/libnatpmp.a vendor/nim-nat-traversal/vendor/libnatpmp-upstream/libnatpmp.a
      ln -s ${pkgs.miniupnpc}/lib/libminiupnpc.a vendor/nim-nat-traversal/vendor/miniupnp/miniupnpc/libminiupnpc.a
      mkdir -p vendor/nim-libbacktrace/install/usr
      ln -s ${nimlibbacktrace}/lib vendor/nim-libbacktrace/install/usr
      ${pkgs.lib.optionalString enableRln ''
        # We don't need to add rln to the search path because lib rln
        #mkdir -p vendor/rln/target/debug
        #ln -s ${rln}/lib/librln.so vendor/rln/target/debug/librln.so
      ''}
      ${pkgs.nim-unwrapped}/bin/nim --version
      # We define the source search path using -p
      # This helps use from having to use $NIMBLE_DIR
      ${pkgs.nim-unwrapped}/bin/nim \
        -p:$(pwd)/vendor/nim-eth \
        -p:$(pwd)/vendor/nim-secp256k1 \
        -p:$(pwd)/vendor/nim-libp2p \
        -p:$(pwd)/vendor/nim-stew \
        -p:$(pwd)/vendor/nimbus-build-system \
        -p:$(pwd)/vendor/nim-nat-traversal \
        -p:$(pwd)/vendor/nim-libbacktrace \
        -p:$(pwd)/vendor/nim-confutils \
        -p:$(pwd)/vendor/nim-chronicles \
        -p:$(pwd)/vendor/nim-faststreams \
        -p:$(pwd)/vendor/nim-chronos \
        -p:$(pwd)/vendor/nim-json-serialization \
        -p:$(pwd)/vendor/nim-serialization \
        -p:$(pwd)/vendor/nimcrypto \
        -p:$(pwd)/vendor/nim-metrics \
        -p:$(pwd)/vendor/nim-stint \
        -p:$(pwd)/vendor/nim-json-rpc \
        -p:$(pwd)/vendor/nim-http-utils \
        -p:$(pwd)/vendor/news \
        -p:$(pwd)/vendor/nim-bearssl \
        -p:$(pwd)/vendor/nim-sqlite3-abi \
        -p:$(pwd)/vendor/nim-web3 \
        -p:$(pwd)/vendor/nim-testutils \
        -p:$(pwd)/vendor/nim-unittest2 \
        -p:$(pwd)/vendor/nim-websock \
        -p:$(pwd)/vendor/nim-zlib \
        -p:$(pwd)/vendor/nim-dnsdisc \
        -p:$(pwd)/vendor/dnsclient.nim/src \
        compile ${pkgs.lib.concatStringsSep " " compileArgs} waku/v2/node/wakunode2.nim
    '';
    installPhase = "
      install -Dt $out/bin build/wakunode
      ${pkgs.lib.optionalString enableRln ''
      # lib rln is loaded on runtime:
      # https://github.com/status-im/nim-waku/blob/dbbc0f750bef23278cfeb1111187e057519efef4/waku/v2/protocol/waku_rln_relay/rln.nim#L9
      install -Dt $out/lib ${rln}/lib/librln.so
    ''}
    ";
  };
in
  wakunode
