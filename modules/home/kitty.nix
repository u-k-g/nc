{ config, pkgs, ... }:

let
  user = config.nc.user;
  theme = config.nc.theme;
  hex = color: "#${color}";
in
{
  home-manager.users.${user.name}.programs.kitty = {
    enable = true;

    font = {
      name = "Iosevka Nerd Font Mono";
      package = pkgs.nerd-fonts.iosevka;
      size = theme.font.size.normal;
    };

    settings = {
      allow_remote_control = true;
      confirm_os_window_close = 0;
      focus_follows_mouse = true;
      mouse_hide_wait = 0;
      copy_on_select = "clipboard";
      window_padding_width = theme.padding;
      hide_window_decorations = "titlebar-only";
      macos_titlebar_color = hex theme.base00;

      scrollback_lines = 100000;
      scrollback_pager = "bat --chop-long-lines";

      cursor = hex theme.base05;
      cursor_text_color = hex theme.base00;
      cursor_shape = "beam";

      url_color = hex theme.base0D;

      strip_trailing_spaces = "always";
      enable_audio_bell = false;
      shell_integration = "no-cursor no-title";

      active_border_color = hex theme.base0A;
      inactive_border_color = hex theme.base01;
      window_border_width = "0pt";
      enabled_layouts = "splits";

      background = hex theme.base00;
      foreground = hex theme.base05;

      selection_background = hex theme.base02;
      selection_foreground = hex theme.base00;

      tab_bar_edge = "top";
      tab_bar_margin_width = 60;
      tab_bar_margin_height = "2 0";
      tab_bar_style = "fade";
      tab_powerline_style = "angled";
      tab_separator = " › ";
      tab_title_template = "{index} {title}";
      active_tab_title_template = "{index} {title}";

      active_tab_background = hex theme.base01;
      active_tab_foreground = hex theme.base05;

      inactive_tab_background = hex theme.base00;
      inactive_tab_foreground = hex theme.base05;

      color0 = hex theme.base00;
      color1 = hex theme.base08;
      color2 = hex theme.base0B;
      color3 = hex theme.base0A;
      color4 = hex theme.base0D;
      color5 = hex theme.base0E;
      color6 = hex theme.base0C;
      color7 = hex theme.base05;
      color8 = hex theme.base03;
      color9 = hex theme.base08;
      color10 = hex theme.base0B;
      color11 = hex theme.base0A;
      color12 = hex theme.base0D;
      color13 = hex theme.base0E;
      color14 = hex theme.base0C;
      color15 = hex theme.base07;
      color16 = hex theme.base09;
      color17 = hex theme.base0F;
      color18 = hex theme.base01;
      color19 = hex theme.base02;
      color20 = hex theme.base04;
      color21 = hex theme.base06;
    };

    keybindings = {
      "cmd+1" = "goto_tab 1";
      "cmd+2" = "goto_tab 2";
      "cmd+3" = "goto_tab 3";
      "cmd+4" = "goto_tab 4";
      "cmd+5" = "goto_tab 5";
      "cmd+6" = "goto_tab 6";
      "cmd+7" = "goto_tab 7";
      "cmd+8" = "goto_tab 8";
      "cmd+9" = "goto_tab 9";
      "cmd+0" = "goto_tab 10";
      "cmd+enter" = "launch --location=vsplit";

      "super+c" = "copy_to_clipboard";
      "super+v" = "paste_from_clipboard";
      "super+t" = "new_tab";
      "super+w" = "close_tab";
      "super+1" = "goto_tab 1";
      "super+2" = "goto_tab 2";
      "super+3" = "goto_tab 3";
      "super+4" = "goto_tab 4";
      "super+5" = "goto_tab 5";
      "super+6" = "goto_tab 6";
      "super+7" = "goto_tab 7";
      "super+8" = "goto_tab 8";
      "super+9" = "goto_tab 9";
      "super+0" = "goto_tab 10";
      "super+enter" = "launch --location=vsplit";
    };
  };
}
