{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "vercel";
  version = "50.32.5";

  src = ./.;

  npmDepsHash = "sha256-Vt9KX+iWU04dPrSv/lTsRVdNBeqDPXSlDPJdNKoMxx4=";

  dontNpmBuild = true;

  meta = {
    description = "The command-line interface for Vercel";
    homepage = "https://vercel.com";
    license = lib.licenses.asl20;
  };
}
