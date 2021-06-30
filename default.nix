{ pkgs ? import (import ./nix/sources.nix).nixpkgs {} }:
let
  # rlnDerivation  = ./import/librln.nix
  wakunode = pkgs.stdenv.mkDerivation rec {
    version = "0.4";
    name = "nim-waku-${version}";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo ="nim-waku";
      rev = "f140a71d6d5e93e73a737a756d2682ee70011cd9"; # = "v${version}"
      sha256 = "092mfwbymyk98wgb180ksq7rbdf5n29mqr0vx7hyai23ss1ndy5a";
    };
    buildInputs = [ pkgs.pcre pkgs.nim ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
    USE_SYSTEM_NIM = 1;

    buildPhase = ''
      export HOME=$TMPDIR
      make libbacktrace

      # This path list and the for loop is for the nimble package manager.
      # Nimble looks for pacakges in the path (could be somewhere else) 
      # vendor/.nimble/pkgs.
      #
      # Since the src is downladed using deepClone = true, all the submoudles
      # exists, but they don't exists in the .git directory so the command
      # `git submodule foreach --recursive --quiet` doesn't work since there is
      # no .git/modules dir
      #  
      # An alternative would be to run 
      # `find . -type f | grep .gitmodules`
      # create the right path for all of these files.
      # TODO use shell scripting to find the packages paths
      # and submoudles
      export NIMBLE_DIR=`readlink -f vendor/.nimble`
      submodules="vendor/news
      vendor/nim-bearssl
      vendor/nim-bearssl/bearssl/csources
      vendor/nim-chronicles
      vendor/nim-chronos
      vendor/nim-confutils
      vendor/nim-eth
      vendor/nim-faststreams
      vendor/nim-http-utils
      vendor/nim-json-rpc
      vendor/nim-json-serialization
      vendor/nim-libbacktrace
      vendor/nim-libbacktrace/vendor/libbacktrace-upstream
      vendor/nim-libbacktrace/vendor/whereami
      vendor/nim-libp2p
      vendor/nim-metrics
      vendor/nim-nat-traversal
      vendor/nim-nat-traversal/vendor/miniupnp
      vendor/nim-secp256k1
      vendor/nim-secp256k1/secp256k1_wrapper/secp256k1
      vendor/nim-serialization
      vendor/nim-sqlite3-abi
      vendor/nim-stew
      vendor/nim-stint
      vendor/nim-testutils
      vendor/nim-unittest2
      vendor/nim-web3
      vendor/nimbus-build-system
      vendor/nimbus-build-system/vendor/Nim
      vendor/nimbus-build-system/vendor/Nim-csources-v1
      vendor/nimbus-build-system/vendor/nimble
      vendor/nimcrypto
      vendor/rln"

      # This for loop createsa file in
      # vendor/.nimble/pkgs/<pkg name>-#head/<pkg name>nimble.link
      # This allows nim to find the sources of its dependencies
      # through nimble
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
      # already exists in nixpkgs but we use the paths that nim expects
      # them to be
      ln -s ${pkgs.libnatpmp}/lib/libnatpmp.a vendor/nim-nat-traversal/vendor/libnatpmp-upstream/libnatpmp.a
      ln -s ${pkgs.miniupnpc}/lib/libminiupnpc.a vendor/nim-nat-traversal/vendor/miniupnp/miniupnpc/libminiupnpc.a

      ${pkgs.nim}/bin/nim c --out:build/wakunode2 -d:chronicles_log_level=DEBUG --verbosity:0 --hints:off -d:release waku/v2/node/wakunode2.nim
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp build/wakunode2 $out/bin/wakunode
    '';
  };
in wakunode
