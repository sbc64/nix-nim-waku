{ pkgs ? import (import ./nix/sources.nix).nixpkgs {} }:
let
in pkgs.stdenv.mkDerivation rec {
  version = "0.4";
  name = "nim-waku";
  src = pkgs.fetchgit {
    leaveDotGit = true;
    deepClone = true;
    url = "https://github.com/status-im/nim-waku";
    rev = "5c58a19f4f50e207dcfbf34f4514cc7e88c709e5";
    sha256 = "cK8Fp+TZ1zUcEgYkmB/72nqG98QU1hfLyIGDYJc8FcM=";
  };
  buildInputs = with pkgs; [
    git
    llvmPackages.libclang 
    cargo 
    rustc
    pcre 
    nim
    libnatpmp
  ];
  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
  LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
  USE_SYSTEM_NIM = 1;
  NIM_PATH= "${pkgs.nim}/bin";

  dontConfigure = true;
  buildPhase = ''
    export HOME=$TMPDIR
    export PATH=$PATH:${pkgs.gcc}/bin:${pkgs.bash}/bin:${pkgs.busybox}/bin:${pkgs.git}/bin:${pkgs.nim}/bin
    export NIMBLE_DIR=`readlink -f vendor/.nimble`
    export NIMBUS_ENV_DIR=`readlink -f vendor/nimbus-build-system/scripts`
    make libbacktrace

    # 
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

    ln -s ${pkgs.libnatpmp}/lib/libnatpmp.a vendor/nim-nat-traversal/vendor/libnatpmp-upstream/libnatpmp.a
    ln -s ${pkgs.miniupnpc}/lib/libminiupnpc.a vendor/nim-nat-traversal/vendor/miniupnp/miniupnpc/libminiupnpc.a

    ls vendor | wc -l
    echo "H"
    echo $submodules
    echo "I"
    mkdir -pv vendor/.nimble/pkgs

    for mod in $submodules; do
      echo $mod
      modName=$(echo -n $mod | awk 'BEGIN { FS = "/" }; {print $NF}')
      echo "Hi $modName"
      pkgDir="$(readlink -f $mod)"
      modPath="$NIMBLE_DIR/pkgs/$modName-#head"
      if [ -d "$pkgDir/src" ]; then
        pkgDir="$pkgDir/src"
      fi
      mkdir -vp $modPath
      echo -e "$pkgDir\n$pkgDir" > "$modPath/$modName.nimble-link"
    done
    nim c --out:build/wakunode2 -d:chronicles_log_level=DEBUG --verbosity:0 --hints:off -d:release waku/v2/node/wakunode2.nim
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp build/wakunode2 $out/bin/wakunode
  '';
}
