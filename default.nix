{ sources ? import ./nix/sources.nix, enableRln ? true }:
let
  nimOverlay = final: prev: {
    nim-unwrapped = prev.nim-unwrapped.overrideAttrs (old: rec {
      pname = "nim-unwrapped";
      version = "1.2.16";
      strictDeps = true;
      patches = [ ./nixbuild.patch ./NIM_CONFIG_DIR.patch ];
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
      overlays = [ nimOverlay ];
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
  rln  = pkgs.rustPlatform.buildRustPackage rec {
    pname = "rln";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "kilic";
      repo = "rln";
      rev = "master";
      sha256 = "q68uaBlsXPjHP65KqPen57yxsEoQNGWf8FmRlVTqWPU=";
    };
    cargoPatches = [ ./cargo-lock.patch ];
    cargoSha256 = "iA9DkHZvvV1O4BsZ2HOL8ocRjEqRrrzfzbQTmrJ4msI=";
  };
  wakunode = pkgs.stdenv.mkDerivation rec {
    # make sure that the commit actually compiles
    #version = "0.7"; # release 0.7 doesn't work
    version = "master";
    pname = "nim-waku";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo ="nim-waku";
      rev = "4421b8de0074574c3740b71a197b4f6eeb90c1c5"; #"v${version}";
      sha256 = "SuKjtUwe+ZFNH3anh7HY9VdJ1IQhs1uvdzHbDLZ00pA="; #pkgs.lib.fakeSha256;
    };
    nativeBuildInputs = with pkgs; [ nim-unwrapped libnatpmp miniupnpc ];
    buildInputs = with pkgs; [ pcre ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath nativeBuildInputs}";
    compileArgs = [
      "--out:build/wakunode"
      "--debugger:native"
      "--d:chronicles_log_level=INFO"
      "--verbosity:0"
      "--hints:off"
      "-d:release"
    ] ++ pkgs.lib.optional enableRln "-d:rln";
    buildPhase = ''
      export HOME=$TMPDIR
      export NIMBLE_DIR=`readlink -f vendor/.nimble`
      submodules=$(cat .gitmodules | grep submodule | cut -f2 -d" " | tr -d ']"')

      # This for loop creates a file in
      # vendor/.nimble/pkgs/<pkg name>-#head/<pkg name>nimble.link
      # This allows nim to find the sources of its dependencies through nimble
      #
      # This for loop is based on https://github.com/status-im/nimbus-build-system/blob/master/scripts/create_nimble_link.sh
      # TLDR linking the src of the vendored packages to a format nimble can read
      for mod in $submodules; do
        pkgName=$(echo -n $mod | awk 'BEGIN { FS = "/" }; {print $NF}')
        pkgSrcDir="$(readlink -f $mod)"
        if [ -d "$pkgSrcDir/src" ]; then
          pkgSrcDir="$pkgSrcDir/src"
        fi
        mkdir -vp "$NIMBLE_DIR/pkgs/$pkgName-#head"
        echo -e "$pkgSrcDir\n$pkgSrcDir" > "$NIMBLE_DIR/pkgs/$pkgName-#head/$pkgName.nimble-link"
      done

      # To avoid building these libraries we just link them with what
      # already exists in nixpkgs but we use the paths that nim compiler expects
      # them to be
      ln -s ${pkgs.libnatpmp}/lib/libnatpmp.a vendor/nim-nat-traversal/vendor/libnatpmp-upstream/libnatpmp.a
      ln -s ${pkgs.miniupnpc}/lib/libminiupnpc.a vendor/nim-nat-traversal/vendor/miniupnp/miniupnpc/libminiupnpc.a
      mkdir -p vendor/nim-libbacktrace/install/usr
      ln -s ${nimlibbacktrace}/lib vendor/nim-libbacktrace/install/usr
      ${pkgs.lib.optionalString enableRln ''
        mkdir -p vendor/rln/target/debug
        ln -s ${rln}/lib/librln.so vendor/rln/target/debug/librln.so
      ''}
      ${pkgs.nim-unwrapped}/bin/nim --version
      ${pkgs.nim-unwrapped}/bin/nim compile ${pkgs.lib.concatStringsSep " " compileArgs} waku/v2/node/wakunode2.nim
    '';
    installPhase = "install -Dt $out/bin build/wakunode";
  };
in wakunode
