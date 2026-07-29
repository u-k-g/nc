{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.modules) mkIf;
  inherit (lib.trivial) const flip;
  user = config.nc.user;
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
    xdg.mimeApps.defaultApplications =
      mkIf pkgs.stdenv.isLinux
      <| flip genAttrs (const "discord.desktop") [
        "x-scheme-handler/discord"
      ];

    home.packages =
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
        discord
      ];

    xdg.dataFile = mkIf pkgs.stdenv.isLinux {
      "applications/helium.desktop" = {
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}
