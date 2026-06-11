{ pkgs, ... }:

{
  imports = [ ./ticket-watch ];

  home.packages = [
    (pkgs.callPackage ./packages/vercel { })
    (pkgs.callPackage ./packages/salesforce-cli { })
    pkgs.heroku
    pkgs.opentofu
    pkgs.google-cloud-sdk
  ];
}
