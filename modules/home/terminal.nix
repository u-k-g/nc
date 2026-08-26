{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.strings) concatMapStringsSep fileContents;
  user = config.nc.user;
  theme = config.nc.theme;
in
{
  home.users.${user.name}.xdg.config.files."tmux/tmux.conf".text = ''
    set -g base-index 1
    setw -g pane-base-index 1
    set -sg escape-time 0
    setw -g mode-keys vi
    set -g mouse on
    unbind C-b
    set -g prefix C-space
    bind C-space send-prefix
    set -g default-shell "${pkgs.nushell}/bin/nu"
    set -g default-terminal "tmux-256color"

    ${concatMapStringsSep "\n" (plugin: "run-shell ${plugin.rtp}") [
      pkgs.tmuxPlugins.yank
      pkgs.tmuxPlugins.resurrect
      pkgs.tmuxPlugins.continuum
    ]}

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
  + fileContents ../../dotfiles/config/tmux/tmux.conf;
}
