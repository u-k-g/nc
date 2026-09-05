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
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;
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
  home.users.${user.name} = mkIf workstation {
    xdg.mime-apps.default-applications =
      mkIf pkgs.stdenv.hostPlatform.isLinux
      <| flip genAttrs (const "discord.desktop") [
        "x-scheme-handler/discord"
      ];

    packages = optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.cinny-desktop
      discord
    ];

    xdg.config.files."Vencord/settings/quickCss.css" = mkIf pkgs.stdenv.hostPlatform.isLinux {
      text = config.nc.theme.discordCss;
    };
  };
}
