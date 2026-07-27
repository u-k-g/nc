{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe;
  user = config.nc.user;
  theme = config.nc.theme;
  hex = color: "#${color}";
  tabBarLeftPadding = 2;
  tabBarRightPadding = 2;
  scrollbackPager = pkgs.writers.writeNuBin "kitty-scrollback-pager" ''
    def main [line_arg?: string] {
      $env.BAT_PAGER = if $line_arg == null {
        "${getExe pkgs.less} -FRX --chop-long-lines"
      } else {
        $"${getExe pkgs.less} -FRX --chop-long-lines ($line_arg)"
      }

      exec ${getExe pkgs.bat} --plain --color=always --paging=always --file-name=scrollback -
    }
  '';
  scrollbackHx = pkgs.writers.writeNuBin "kitty-scrollback-hx" ''
    def main [] {
      let file = (mktemp --tmpdir kitty-scrollback.XXXXXX)
      open --raw /dev/stdin | save --raw --force $file

      let line_count = (open --raw $file | lines | length)
      let cursor_line = ([$line_count 1] | math max)

      ^${getExe pkgs.helix} $"+($cursor_line)" $file
      let exit_code = $env.LAST_EXIT_CODE
      rm --force $file
      exit $exit_code
    }
  '';
in
{
  home-manager.users.${user.name} = {
    programs.kitty = {
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
        macos_option_as_alt = "both";

        scrollback_lines = 100000;
        scrollback_pager = "${scrollbackPager}/bin/kitty-scrollback-pager +INPUT_LINE_NUMBER";

        cursor = hex theme.base05;
        cursor_text_color = hex theme.base00;
        cursor_shape = "beam";
        cursor_trail = 3;
        cursor_trail_decay = "0.1 0.4";

        url_color = hex theme.base0D;
        detect_urls = true;
        open_url_modifiers = "cmd";
        "mouse_map cmd+left press grabbed" = "discard_event";
        "mouse_map cmd+left release grabbed,ungrabbed" = "mouse_handle_click link";
        "mouse_map super+left press grabbed" = "discard_event";
        "mouse_map super+left release grabbed,ungrabbed" = "mouse_handle_click link";

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
        tab_bar_margin_width = 0;
        tab_bar_margin_height = "2 0";
        tab_bar_style = "custom";
        tab_powerline_style = "angled";
        tab_separator = ''"   "'';
        tab_title_template = "{custom}";
        active_tab_title_template = "{fmt.noitalic}{fmt.bold}{custom}{fmt.nobold}";

        active_tab_background = hex theme.base00;
        active_tab_foreground = hex theme.base05;

        inactive_tab_background = hex theme.base00;
        inactive_tab_foreground = hex theme.base03;

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

      keybindings =
        (
          if pkgs.stdenv.isLinux then
            {
              "ctrl+1" = "goto_tab 1";
              "ctrl+2" = "goto_tab 2";
              "ctrl+3" = "goto_tab 3";
              "ctrl+4" = "goto_tab 4";
              "ctrl+5" = "goto_tab 5";
              "ctrl+6" = "goto_tab 6";
              "ctrl+7" = "goto_tab 7";
              "ctrl+8" = "goto_tab 8";
              "ctrl+9" = "goto_tab 9";
              "ctrl+0" = "goto_tab 10";
              "ctrl+shift+k" = "send_text all \\x0c";
              "ctrl+shift+t" = "new_tab";
              "ctrl+shift+w" = "close_tab";
            }
          else
            { }
        )
        // {
          "super+c" = "copy_to_clipboard";
          "super+k" = "combine : clear_terminal to_cursor_scroll active : send_text all \\x0c";
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
          "alt+backspace" = "send_text all \\x17";
          "ctrl+shift+x" =
            "launch --stdin-source=@screen_scrollback --type=overlay ${scrollbackHx}/bin/kitty-scrollback-hx";
        };

      extraConfig = ''
        symbol_map U+2190-U+21FF Iosevka Nerd Font Mono
        symbol_map U+2200-U+22FF Iosevka Nerd Font Mono
        symbol_map U+2300-U+23FF Iosevka Nerd Font Mono
        symbol_map U+2460-U+24FF Iosevka Nerd Font Mono
        symbol_map U+2500-U+259F Iosevka Nerd Font Mono
        symbol_map U+25A0-U+25FF Iosevka Nerd Font Mono
        symbol_map U+2600-U+27BF Iosevka Nerd Font Mono
        symbol_map U+27C0-U+27FF Iosevka Nerd Font Mono
        symbol_map U+2800-U+28FF Iosevka Nerd Font Mono
        symbol_map U+2900-U+297F Iosevka Nerd Font Mono
        symbol_map U+2A00-U+2AFF Iosevka Nerd Font Mono
        symbol_map U+E000-U+F8FF Iosevka Nerd Font Mono
        symbol_map U+F0000-U+FFFFD Iosevka Nerd Font Mono
        symbol_map U+100000-U+10FFFD Iosevka Nerd Font Mono
      '';
    };

    xdg.configFile."kitty/tab_bar.py".text = ''
      import os
      import socket
      from os.path import basename

      from kitty.tab_bar import as_rgb, draw_tab_with_separator


      FG = as_rgb(0x${theme.base05})
      MUTED = as_rgb(0x${theme.base03})
      LEFT_PADDING = ${toString tabBarLeftPadding}
      RIGHT_PADDING = ${toString tabBarRightPadding}


      def draw_title(data):
          tab = data.get("tab")
          title = str(data.get("title") or "")
          index = data.get("index") or ""

          exe = ""
          wd = ""
          if tab is not None:
              exe = str(getattr(tab, "active_exe", "") or "")
              wd = str(getattr(tab, "active_wd", "") or "")

          exe_name = basename(exe)
          if exe_name == "nu" and wd:
              name = basename(wd.rstrip("/")) or wd
          else:
              name = exe_name or title

          return f" {index} {name}"


      def draw_right_status(screen):
          user = os.environ.get("USER") or os.environ.get("LOGNAME") or "user"
          host = socket.gethostname().split(".", 1)[0] or "host"
          parts = [
              (MUTED, "["),
              (FG, user),
              (MUTED, "@"),
              (FG, host),
              (MUTED, "]"),
          ]
          width = sum(len(text) for _, text in parts)
          if screen.cursor.x + width + RIGHT_PADDING >= screen.columns:
              return

          screen.draw(" " * (screen.columns - screen.cursor.x - width - RIGHT_PADDING))
          screen.cursor.bold = False
          screen.cursor.italic = False
          screen.cursor.bg = 0
          for color, text in parts:
              screen.cursor.fg = color
              screen.draw(text)


      def draw_tab(draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data):
          if index == 1 and screen.cursor.x == 0 and LEFT_PADDING > 0:
              screen.draw(" " * LEFT_PADDING)
              before = screen.cursor.x

          end = draw_tab_with_separator(
              draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
          )
          if is_last:
              draw_right_status(screen)
          return end
    '';
  };
}
