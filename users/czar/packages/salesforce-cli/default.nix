{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "salesforce-cli";
  version = "2.130.9";

  src = ./.;

  npmDepsHash = "sha256-VX6USmeEFwwFX3caHI4z3CawsN3r6TM75tjqk46xS1w=";

  dontNpmBuild = true;
  dontNpmPrune = true;

  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/salesforce-cli/node_modules/.bin/sf $out/bin/sf
    ln -s $out/lib/node_modules/salesforce-cli/node_modules/.bin/sfdx $out/bin/sfdx
  '';

  meta = {
    description = "Salesforce CLI";
    homepage = "https://developer.salesforce.com/tools/salesforcecli";
    license = lib.licenses.bsd3;
  };
}
