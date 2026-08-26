{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  user = config.nc.user;
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
in
{
  home.users.${user.name} = {
    packages =
      with pkgs;
      [
        kitty
        obsidian
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        pkgs.ghostty-bin
      ]
      ++ optionals pkgs.stdenv.isLinux [
        pkgs.ghostty
        heliumBrowser
        pkgs.orca-slicer
        pkgs.ungoogled-chromium
        zed-editor
      ];

    xdg.data.files = lib.modules.mkIf pkgs.stdenv.isLinux {
      "applications/helium.desktop" = {
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}
