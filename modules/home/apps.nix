{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals singleton;
  user = config.nc.user;
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;
  heliumBrowser = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium-widevine;
  workstationPackages =
    singleton pkgs.obsidian
    ++ (if pkgs.stdenv.hostPlatform.isDarwin then singleton pkgs.ghostty-bin else [ ])
    ++ optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.ghostty
      pkgs.orca-slicer
      pkgs.ungoogled-chromium
      pkgs.zed-editor
    ];
in
{
  home.users.${user.name} = {
    packages = [
      heliumBrowser
      pkgs.kitty
    ]
    ++ optionals workstation workstationPackages;

    xdg.data.files = lib.modules.mkIf pkgs.stdenv.hostPlatform.isLinux {
      "applications/helium.desktop" = {
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}
