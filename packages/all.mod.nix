{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.fast-workspace-switch = pkgs.callPackage ./fast-workspace-switch { };
    };
}
