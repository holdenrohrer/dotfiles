{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ./packages/vercel { })
  ];
}
