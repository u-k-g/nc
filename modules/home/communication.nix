{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) optional;
  inherit (lib.modules) mkIf;
  inherit (lib.trivial) const flip;
  user = config.nc.user;
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

    home.packages = optional pkgs.stdenv.isLinux discord;

    xdg.configFile."Vencord/settings/quickCss.css".text =
      mkIf pkgs.stdenv.isLinux config.nc.theme.discordCss;
  };
}
