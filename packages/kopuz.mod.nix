{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      upstream = inputs.kopuz.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      packages.kopuz =
        if pkgs.stdenv.hostPlatform.isDarwin then
          pkgs.callPackage ./kopuz { kopuz = upstream; }
        else
          upstream;
    };
}
