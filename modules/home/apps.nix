{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) hiPrio optionals;
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
  prismlauncherGamemode = hiPrio (
    pkgs.writeShellScriptBin "prismlauncher" ''
      exec ${pkgs.gamemode}/bin/gamemoderun ${pkgs.prismlauncher}/bin/prismlauncher "$@"
    ''
  );
in
{
  home-manager.users.${user.name} = {
    home.packages =
      with pkgs;
      [
        kitty
        obsidian
        # Launch PrismLauncher through GameMode so its Minecraft JVM child inherits
        # GameMode's performance request. If FPS/frametimes get worse, compare
        # against a normal launch by running `${pkgs.prismlauncher}/bin/prismlauncher`.
        prismlauncherGamemode
        zed-editor
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        pkgs.ghostty-bin
      ]
      ++ optionals pkgs.stdenv.isLinux [
        pkgs.freecad
        pkgs.ghostty
        heliumBrowser
        pkgs.kicad
        pkgs.orca-slicer
        pkgs.ungoogled-chromium
        pkgs.vesktop
      ];

    xdg.configFile = {
      "FreeCAD".source = dotfiles + /config/FreeCAD;
    };

    xdg.desktopEntries.prismlauncher-gamemode = lib.mkIf pkgs.stdenv.isLinux {
      name = "PrismLauncher (GameMode)";
      genericName = "Minecraft Launcher";
      comment = "Launch PrismLauncher through GameMode";
      exec = "${prismlauncherGamemode}/bin/prismlauncher %u";
      terminal = false;
      categories = [ "Game" ];
    };

    xdg.dataFile = lib.mkIf pkgs.stdenv.isLinux {
      "applications/helium.desktop" = {
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}
