{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
    in
    {
      packages = optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
        suzuri = pkgs.callPackage (
          {
            buildFHSEnv,
            fetchurl,
            lib,
            runCommand,
            symlinkJoin,
          }:
          let
            archive = fetchurl {
              url = "https://github.com/harrywang/suzuri/releases/download/suzuri-v0.4.10/suzuri-linux-x86_64.tar.gz";
              hash = "sha256-ZewWsT+LUjU3T27Cq5XVjkBU2TT5TTsN42gv/yTFezc=";
            };
            files = runCommand "suzuri-files-0.4.10" { } ''
              mkdir -p "$out"
              tar -xzf ${archive} -C "$out"
            '';
            runtime = buildFHSEnv {
              name = "suzuri";
              targetPkgs = p: p.zed-editor.buildInputs ++ [
                p.stdenv.cc.cc.lib
                p.vulkan-loader
              ];
              runScript = "${files}/suzuri.app/bin/suzuri";
            };
          in
          symlinkJoin {
            name = "suzuri-with-desktop";
            paths = lib.lists.singleton runtime;
            postBuild = ''
              mkdir -p "$out/share"
              ln -s ${files}/suzuri.app/share/applications "$out/share/applications"
              ln -s ${files}/suzuri.app/share/icons "$out/share/icons"
            '';
            meta = {
              description = "Writing environment built on Zed";
              homepage = "https://github.com/harrywang/suzuri";
              license = lib.licenses.gpl3Plus;
              platforms = lib.lists.singleton "x86_64-linux";
              mainProgram = "suzuri";
            };
          }
        ) { };
      };
    };
}
