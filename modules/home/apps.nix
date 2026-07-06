{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) optionals;
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
  discord =
    (pkgs.discord.override {
      withOpenASAR = true;
      withVencord = true;
    }).overrideAttrs
      (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];

        postFixup = ''
          wrapProgram $out/opt/Discord/Discord \
            --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
            --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
        '';
      });
in
{
  home-manager.users.${user.name} = {
    home.packages =
      with pkgs;
      [
        kitty
        obsidian
        zed-editor
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        pkgs.ghostty-bin
      ]
      ++ optionals pkgs.stdenv.isLinux [
        pkgs.freecad
        pkgs.ghostty
        heliumBrowser
        pkgs.orca-slicer
        pkgs.ungoogled-chromium
        discord
      ];

    xdg.configFile = {
      "FreeCAD".source = dotfiles + /config/FreeCAD;
    };

    xdg.dataFile = lib.mkIf pkgs.stdenv.isLinux {
      "applications/helium.desktop" = {
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}
