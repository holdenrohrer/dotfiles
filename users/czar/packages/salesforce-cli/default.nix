{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "salesforce-cli";
  version = "2.73.3";

  src = ./.;

  npmDepsHash = lib.fakeHash;

  dontNpmBuild = true;

  meta = {
    description = "Salesforce CLI";
    homepage = "https://developer.salesforce.com/tools/salesforcecli";
    license = lib.licenses.bsd3;
  };
}
