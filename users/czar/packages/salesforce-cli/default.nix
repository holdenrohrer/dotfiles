{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "salesforce-cli";
  version = "2.73.3";

  src = ./.;

  npmDepsHash = "sha256-pq5wqyqXIf8OpBwAvMI4z3rgZ/CH/D3FVpLTL23MSIw=";

  dontNpmBuild = true;

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
