{ lib, stdenvNoCC, fetchurl, makeWrapper, glibc, stdenv }:

# oh-my-pi (omp) ships a single-file Bun-compiled executable per release.
#
# It is a generic-linux glibc binary, but we must NOT patchelf it: Bun appends
# the JS payload to the end of the ELF and locates it by byte offset, so any ELF
# rewrite (autoPatchelfHook / --set-interpreter) invalidates the trailer and the
# app silently degrades to a bare Bun runtime. Instead we keep the binary byte
# for byte and launch it through the Nix glibc loader with an explicit
# --library-path, which leaves the payload intact.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "omp";
  version = "17.2.12";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
    hash = "sha256-bHUzG/CdWp6UM71ZKz7pk9dRoV1bdFDBozTMBoSZbzA=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/omp
    makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/omp \
      --add-flags "--library-path ${lib.makeLibraryPath [ glibc stdenv.cc.cc.lib ]}" \
      --add-flags "$out/libexec/omp"
    runHook postInstall
  '';

  meta = {
    description = "oh-my-pi (omp): a batteries-included terminal AI coding agent";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "omp";
  };
})
