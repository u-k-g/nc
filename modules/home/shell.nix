{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  nushellHelperDir = "${user.homeDirectory}/.config/nushell";
  nushellConfig = builtins.replaceStrings
    [
      "@nushellHelperDir@"
      "@nushellDarwinConfig@"
    ]
    [
      nushellHelperDir
      (if pkgs.stdenv.hostPlatform.isDarwin then ''source "${nushellHelperDir}/misc-darwin.nu"'' else "")
    ]
    (builtins.readFile (dotfiles + /config/nushell/config.nu));
  nushellIntegrations = pkgs.runCommand "nushell-integrations.nu" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    {
      ${pkgs.atuin}/bin/atuin init nu
      printf '\nsource ${nushellHelperDir}/atuin-fix.nu\n'
      ${pkgs.zoxide}/bin/zoxide init nushell --cmd cd
      ${pkgs.carapace}/bin/carapace _carapace nushell
    } > $out

    substituteInPlace $out \
      --replace-quiet '^atuin' '^${pkgs.atuin}/bin/atuin' \
      --replace-quiet '^zoxide' '^${pkgs.zoxide}/bin/zoxide' \
      --replace-quiet '^carapace' '^${pkgs.carapace}/bin/carapace'
  '';
in
{
  home-manager.users.${user.name} = {
    programs.atuin = {
      enable = true;
      enableNushellIntegration = false;
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = false;
    };

    programs.carapace = {
      enable = true;
      enableNushellIntegration = false;
    };

    programs.nushell = {
      enable = true;
      configFile.text = nushellConfig;
      envFile.source = dotfiles + /config/nushell/env.nu;
    };

    xdg.configFile = {
      "atuin/config.toml".source = dotfiles + /config/atuin/config.toml;
      "nushell/integrations.nu".source = nushellIntegrations;
      "nushell/misc.nu".source = dotfiles + /config/nushell/misc.nu;
      "nushell/misc-darwin.nu".source = dotfiles + /config/nushell/misc-darwin.nu;
      "nushell/prompts.nu".source = dotfiles + /config/nushell/prompts.nu;
      "nushell/fcdiff.nu" = {
        source = dotfiles + /config/nushell/fcdiff.nu;
        executable = true;
      };
      "nushell/atuin-fix.nu".source = dotfiles + /config/nushell/atuin-fix.nu;
    };

    home.sessionVariables = {
      DENO_CONFIG = "${user.homeDirectory}/.config/deno/config.json";
    };
  };
}
