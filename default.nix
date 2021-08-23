{ pkgs ? import (import ./nix/sources.nix).nixpkgs {} }:
let
  # rlnDerivation  = ./import/librln.nix
  wakunode = pkgs.stdenv.mkDerivation rec {
    version = "master"; # "0.5.1";
    name = "nim-waku-${version}";
    src = pkgs.fetchFromGitHub {
      fetchSubmodules = true;
      owner = "status-im";
      repo ="nim-waku";
      rev = "6ebe26ad0587d56a87a879d89b7328f67f048911"; #"v${version}";
      sha256 = "187ai7cwa5bhiczyf5wgsnkjrhsgjba7dn9mn5dj9awqk14jd0bi"; #pkgs.lib.fakeSha256;
    };
    nativeBuildInputs = [ pkgs.pcre pkgs.nim pkgs.libnatpmp pkgs.miniupnpc ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath nativeBuildInputs}";
    buildPhase = ''
      export HOME=$TMPDIR
      make libbacktrace
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

      ${pkgs.nim}/bin/nim c --out:build/wakunode2 --debugger:native -d:chronicles_log_level=DEBUG --verbosity:0 --hints:off -d:release waku/v2/node/wakunode2.nim
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp build/wakunode2 $out/bin/wakunode
    '';
  };
in wakunode
