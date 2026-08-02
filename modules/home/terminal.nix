{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) readFile;
  user = config.nc.user;
  theme = config.nc.theme;
in
{
  home-manager.users.${user.name}.programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    mouse = true;
    prefix = "C-space";
    shell = "${pkgs.nushell}/bin/nu";
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      yank
      resurrect
      continuum
    ];

    extraConfig = ''
      set -g @theme_bg "#${theme.base00}"
      set -g @theme_bg_dark "#${theme.base00}"
      set -g @theme_bg_light "#${theme.base01}"
      set -g @theme_bg_highlight "#${theme.base02}"
      set -g @theme_fg "#${theme.base05}"
      set -g @theme_fg_dim "#${theme.base04}"
      set -g @theme_fg_muted "#${theme.base03}"
      set -g @theme_accent "#${theme.base0A}"
      set -g @theme_accent_alt "#${theme.base0D}"
      set -g @theme_error "#${theme.base08}"
      set -g @theme_warning "#${theme.base0A}"
      set -g @theme_info "#${theme.base0D}"
      set -g @theme_success "#${theme.base0B}"
      setw -g clock-mode-colour "#${theme.base0A}"
    ''
    + readFile ../../dotfiles/config/tmux/tmux.conf;
  };
}
