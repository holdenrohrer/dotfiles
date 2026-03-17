{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ./packages/vercel { })
    (pkgs.callPackage ./packages/salesforce-cli { })
  ];
}
