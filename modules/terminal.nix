{ config, pkgs, ... }:

let
  user = config.nc.user;
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

    extraConfig = builtins.readFile ../dotfiles/config/tmux/tmux.conf;
  };
}
