{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../dotfiles;
in
{
  home-manager.users.${user.name} = {
    programs.atuin = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.nushell = {
      enable = true;
      configFile.source = dotfiles + /config/nushell/config.nu;
      envFile.source = dotfiles + /config/nushell/env.nu;
    };

    xdg.configFile = {
      "atuin/config.toml".source = dotfiles + /config/atuin/config.toml;
      "nushell/misc.nu".source = dotfiles + /config/nushell/misc.nu;
      "nushell/misc-darwin.nu".source = dotfiles + /config/nushell/misc-darwin.nu;
      "nushell/prompts.nu".source = dotfiles + /config/nushell/prompts.nu;
      "nushell/atuin-fix.nu".source = dotfiles + /config/nushell/atuin-fix.nu;
    };

    home.sessionVariables = {
      DENO_CONFIG = "${user.homeDirectory}/.config/deno/config.json";
    };
  };
}
