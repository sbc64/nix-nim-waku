{ pkgs ? import (import ./nix/sources.nix).nixpkgs {} }:
let
in {
  waku = pkgs.stdenv.mkDerivation rec {
    name = "nim-waku";
    src = pkgs.fetchgit {
      #deepClone = true;
      url = "https://github.com/status-im/nim-waku";
      rev ="900d53f9df79c9abd81e6b021c8057ab343adb5a";
      sha256 = "18643dcvmhyva43v6vnl7y6jhm0fr8ddr9vmlwwr29yp45bxm33d";
    };
    buildInputs = [  pkgs.git pkgs.llvmPackages.libclang pkgs.cargo pkgs.rustc pkgs.pcre pkgs.nim ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
    
    dontConfigure = true;
    buildPhase = ''
      export HOME=$TMPDIR
      export PATH=$PATH:${pkgs.gcc}/bin:${pkgs.bash}/bin:${pkgs.busybox}/bin:${pkgs.git}/bin
      patchShebangs vendor/nimbus-build-system/scripts/build_nim.sh
      patchShebangs vendor/nimbus-build-system/scripts/env.sh
      mkdir build
      make deps
      #vendor/nimbus-build-system/scripts/env.sh ${pkgs.nim}/bin/nim wakunode2  --verbosity:1 -d:usePcreHeader --passL:-lpcre -d:release waku.nims
      ${pkgs.nim}/bin/nim c --out:build/wakunode2 -d:chronicles_log_level=DEBUG --verbosity:1 --hints:off -d:usePcreHeader --passL:-lpcre -d:release waku/v2/node/wakunode2.nim
    '';
    installPhase = ''
      ls
    '';
  };
}
