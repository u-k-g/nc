{ inputs, ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
      inherit (lib.lists) singleton;
    in
    {
      packages = optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        paneru = inputs.paneru.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (
          {
            nativeBuildInputs ? [ ],
            postInstall ? "",
            ...
          }:
          {
            nativeBuildInputs = nativeBuildInputs ++ singleton pkgs.makeWrapper;
            postInstall = postInstall + ''
              wrapProgram $out/bin/paneru \
                --set RUST_LOG "warn,paneru::manager=info,paneru::ecs::systems=info"
            '';
          }
        );
      };
    };
}
