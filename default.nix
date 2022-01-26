{ pkgs ? import (import ./nix/sources.nix).nixpkgs {} }:
let
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
    version = "0.7";
    pname = "nim-waku";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo ="nim-waku";
      rev = "v${version}";
      sha256 = "nbDlPBDtASwstAKVicfFSVFmo18RguMHNApKRjdT1dU="; # pkgs.lib.fakeSha256;
    };
    nativeBuildInputs = with pkgs; [ nim libnatpmp miniupnpc ];
    buildInputs = with pkgs; [ pcre ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath nativeBuildInputs}";
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

      ${pkgs.nim}/bin/nim c --out:build/wakunode2 --debugger:native -d:chronicles_log_level=DEBUG --verbosity:0 --hints:off -d:release waku/v2/node/wakunode2.nim
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp build/wakunode2 $out/bin/wakunode
    '';
  };
in wakunode
