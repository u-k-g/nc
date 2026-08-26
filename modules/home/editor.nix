{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.trivial) importJSON;
  user = config.nc.user;
  theme = config.nc.theme;
  dotfiles = ../../dotfiles;
  json = pkgs.formats.json { };
  clipboardProvider = if pkgs.stdenv.isLinux then "wayland" else "pasteboard";
  zedKeymapSource = dotfiles + /config/zed/keymap.json;
  zedSettingsSource = dotfiles + /config/zed/settings.json;
  zedSettingsFile =
    json.generate "zed-settings-${theme.slug}.json"
    <| recursiveUpdate (importJSON zedSettingsSource) {
      theme = {
        mode = "dark";
        light = "NC ${theme.name}";
        dark = "NC ${theme.name}";
      };
    };
  zedThemeFile = json.generate "nc-${theme.slug}.json" {
    "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
    name = "NC ${theme.name}";
    author = "NC";
    themes = lib.lists.singleton {
      name = "NC ${theme.name}";
      appearance = "dark";
      style = {
        background = "#${theme.base00}";
        foreground = "#${theme.base05}";
        border = "#${theme.base02}";
        "border.variant" = "#${theme.base01}";
        "border.focused" = "#${theme.base0A}";
        "border.selected" = "#${theme.base0D}";
        "elevated_surface.background" = "#${theme.base01}";
        "surface.background" = "#${theme.base01}";
        "element.background" = "#${theme.base00}";
        "element.hover" = "#${theme.base01}";
        "element.active" = "#${theme.base02}";
        "element.selected" = "#${theme.base02}";
        "element.disabled" = "#${theme.base01}";
        "drop_target.background" = "#${theme.base02}";
        "ghost_element.hover" = "#${theme.base01}";
        "ghost_element.active" = "#${theme.base02}";
        "ghost_element.selected" = "#${theme.base02}";
        text = "#${theme.base05}";
        "text.muted" = "#${theme.base04}";
        "text.placeholder" = "#${theme.base03}";
        "text.disabled" = "#${theme.base03}";
        "text.accent" = "#${theme.base0D}";
        icon = "#${theme.base05}";
        "icon.muted" = "#${theme.base04}";
        "icon.disabled" = "#${theme.base03}";
        "icon.placeholder" = "#${theme.base03}";
        "icon.accent" = "#${theme.base0D}";
        "status_bar.background" = "#${theme.base01}";
        "title_bar.background" = "#${theme.base00}";
        "toolbar.background" = "#${theme.base00}";
        "tab_bar.background" = "#${theme.base00}";
        "tab.inactive_background" = "#${theme.base00}";
        "tab.active_background" = "#${theme.base01}";
        "search.match_background" = "#${theme.base02}";
        "panel.background" = "#${theme.base00}";
        "panel.focused_border" = "#${theme.base0A}";
        "pane.focused_border" = "#${theme.base0A}";
        "scrollbar.thumb.background" = "#${theme.base03}";
        "scrollbar.thumb.hover_background" = "#${theme.base04}";
        "editor.foreground" = "#${theme.base05}";
        "editor.background" = "#${theme.base00}";
        "editor.gutter.background" = "#${theme.base00}";
        "editor.subheader.background" = "#${theme.base01}";
        "editor.active_line.background" = "#${theme.base01}";
        "editor.highlighted_line.background" = "#${theme.base01}";
        "editor.line_number" = "#${theme.base03}";
        "editor.active_line_number" = "#${theme.base0A}";
        "editor.invisible" = "#${theme.base03}";
        "editor.wrap_guide" = "#${theme.base02}";
        "editor.active_wrap_guide" = "#${theme.base03}";
        "editor.document_highlight.read_background" = "#${theme.base01}";
        "editor.document_highlight.write_background" = "#${theme.base02}";
        "terminal.background" = "#${theme.base00}";
        "terminal.foreground" = "#${theme.base05}";
        "terminal.bright_foreground" = "#${theme.base06}";
        "terminal.dim_foreground" = "#${theme.base04}";
        "terminal.ansi.black" = "#${theme.base00}";
        "terminal.ansi.red" = "#${theme.base08}";
        "terminal.ansi.green" = "#${theme.base0B}";
        "terminal.ansi.yellow" = "#${theme.base0A}";
        "terminal.ansi.blue" = "#${theme.base0D}";
        "terminal.ansi.magenta" = "#${theme.base0E}";
        "terminal.ansi.cyan" = "#${theme.base0C}";
        "terminal.ansi.white" = "#${theme.base05}";
        "terminal.ansi.bright_black" = "#${theme.base03}";
        "terminal.ansi.bright_red" = "#${theme.base08}";
        "terminal.ansi.bright_green" = "#${theme.base0B}";
        "terminal.ansi.bright_yellow" = "#${theme.base0A}";
        "terminal.ansi.bright_blue" = "#${theme.base0D}";
        "terminal.ansi.bright_magenta" = "#${theme.base0E}";
        "terminal.ansi.bright_cyan" = "#${theme.base0C}";
        "terminal.ansi.bright_white" = "#${theme.base07}";
        "link_text.hover" = "#${theme.base0D}";
        "conflict" = "#${theme.base09}";
        "conflict.background" = "#${theme.base01}";
        "created" = "#${theme.base0B}";
        "created.background" = "#${theme.base01}";
        "deleted" = "#${theme.base08}";
        "deleted.background" = "#${theme.base01}";
        "error" = "#${theme.base08}";
        "error.background" = "#${theme.base01}";
        "hidden" = "#${theme.base03}";
        "hidden.background" = "#${theme.base00}";
        "hint" = "#${theme.base0C}";
        "hint.background" = "#${theme.base01}";
        "ignored" = "#${theme.base03}";
        "ignored.background" = "#${theme.base00}";
        "info" = "#${theme.base0D}";
        "info.background" = "#${theme.base01}";
        "modified" = "#${theme.base0A}";
        "modified.background" = "#${theme.base01}";
        "predictive" = "#${theme.base03}";
        "predictive.background" = "#${theme.base00}";
        "renamed" = "#${theme.base0D}";
        "renamed.background" = "#${theme.base01}";
        "success" = "#${theme.base0B}";
        "success.background" = "#${theme.base01}";
        "unreachable" = "#${theme.base04}";
        "unreachable.background" = "#${theme.base00}";
        "warning" = "#${theme.base0A}";
        "warning.background" = "#${theme.base01}";
        players = lib.lists.singleton {
          cursor = "#${theme.base0D}";
          background = "#${theme.base02}";
          selection = "#${theme.base03}";
        };
        syntax = {
          attribute.color = "#${theme.base0A}";
          boolean.color = "#${theme.base09}";
          comment = {
            color = "#${theme.base03}";
            font_style = "italic";
          };
          constant.color = "#${theme.base09}";
          constructor.color = "#${theme.base0D}";
          embedded.color = "#${theme.base05}";
          emphasis = {
            color = "#${theme.base05}";
            font_style = "italic";
          };
          "emphasis.strong" = {
            color = "#${theme.base05}";
            font_weight = 700;
          };
          enum.color = "#${theme.base0A}";
          function.color = "#${theme.base0D}";
          hint.color = "#${theme.base0C}";
          keyword.color = "#${theme.base0E}";
          label.color = "#${theme.base0E}";
          link_text.color = "#${theme.base0D}";
          link_uri.color = "#${theme.base0C}";
          number.color = "#${theme.base09}";
          operator.color = "#${theme.base05}";
          predictive.color = "#${theme.base03}";
          preproc.color = "#${theme.base0E}";
          primary.color = "#${theme.base05}";
          property.color = "#${theme.base08}";
          punctuation.color = "#${theme.base04}";
          string.color = "#${theme.base0B}";
          "string.escape".color = "#${theme.base0C}";
          "string.regex".color = "#${theme.base0C}";
          tag.color = "#${theme.base0A}";
          text.color = "#${theme.base05}";
          title.color = "#${theme.base0D}";
          type.color = "#${theme.base0A}";
          variable.color = "#${theme.base08}";
          "variable.special".color = "#${theme.base0E}";
          variant.color = "#${theme.base0A}";
        };
      };
    };
  };
in
{
  home.users.${user.name} = {
    packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.wl-clipboard ];

    xdg.config.files."helix/config.toml" = {
      generator = (pkgs.formats.toml { }).generate "helix-config.toml";
      value = {
        theme = "nc";

        editor = {
          auto-completion = false;
          bufferline = "multiple";
          color-modes = true;
          cursorline = true;
          idle-timeout = 1;
          shell = [
            "nu"
            "--commands"
          ];
          text-width = 100;
          clipboard-provider = clipboardProvider;

          file-picker.hidden = false;

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          statusline.mode = {
            insert = "INSERT";
            normal = "NORMAL";
            select = "SELECT";
          };

          indent-guides = {
            character = "▏";
            render = true;
          };

          whitespace = {
            characters.tab = "→";
            render.tab = "all";
          };

          soft-wrap.enable = true;
        };

        keys.normal.b = ":echo %sh{git blame --date=short -L %{cursor_line},+1 %{buffer_name}}";
      };
    };

    xdg.config.files = {
      "helix/themes".type = "directory";
      "helix/languages.toml".source = dotfiles + /config/helix/languages.toml;
      "helix/themes/nc.toml".text = ''
        "ui.background" = { bg = "base00" }
        "ui.text" = "base05"
        "ui.text.focus" = { fg = "base05", modifiers = ["bold"] }
        "ui.cursor" = { fg = "base00", bg = "base05" }
        "ui.cursor.match" = { fg = "base00", bg = "base0A" }
        "ui.cursorline.primary" = { bg = "base01" }
        "ui.selection" = { bg = "base02" }
        "ui.linenr" = "base03"
        "ui.linenr.selected" = "base0A"
        "ui.statusline" = { fg = "base05", bg = "base01" }
        "ui.statusline.inactive" = { fg = "base04", bg = "base00" }
        "ui.statusline.normal" = { fg = "base00", bg = "base0D", modifiers = ["bold"] }
        "ui.statusline.insert" = { fg = "base00", bg = "base0B", modifiers = ["bold"] }
        "ui.statusline.select" = { fg = "base00", bg = "base0E", modifiers = ["bold"] }
        "ui.bufferline" = { fg = "base04", bg = "base00" }
        "ui.bufferline.active" = { fg = "base05", bg = "base02", modifiers = ["bold"] }
        "ui.popup" = { fg = "base05", bg = "base01" }
        "ui.window" = "base03"
        "ui.help" = { fg = "base05", bg = "base01" }
        "ui.menu" = { fg = "base05", bg = "base01" }
        "ui.menu.selected" = { fg = "base00", bg = "base0D" }
        "ui.virtual.whitespace" = "base03"
        "ui.virtual.indent-guide" = "base02"
        "ui.virtual.inlay-hint" = "base04"
        "diagnostic.error" = { underline = { color = "base08", style = "curl" } }
        "diagnostic.warning" = { underline = { color = "base0A", style = "curl" } }
        "diagnostic.info" = { underline = { color = "base0D", style = "curl" } }
        "diagnostic.hint" = { underline = { color = "base0C", style = "curl" } }
        error = "base08"
        warning = "base0A"
        info = "base0D"
        hint = "base0C"
        comment = { fg = "base03", modifiers = ["italic"] }
        keyword = "base0E"
        "keyword.control" = "base0E"
        function = "base0D"
        "function.macro" = "base0C"
        string = "base0B"
        "constant.numeric" = "base09"
        constant = "base09"
        type = "base0A"
        constructor = "base0A"
        variable = "base08"
        "variable.builtin" = "base09"
        namespace = "base0D"
        attribute = "base0A"
        tag = "base0A"
        operator = "base05"
        punctuation = "base04"

        [palette]
        base00 = "#${theme.base00}"
        base01 = "#${theme.base01}"
        base02 = "#${theme.base02}"
        base03 = "#${theme.base03}"
        base04 = "#${theme.base04}"
        base05 = "#${theme.base05}"
        base06 = "#${theme.base06}"
        base07 = "#${theme.base07}"
        base08 = "#${theme.base08}"
        base09 = "#${theme.base09}"
        base0A = "#${theme.base0A}"
        base0B = "#${theme.base0B}"
        base0C = "#${theme.base0C}"
        base0D = "#${theme.base0D}"
        base0E = "#${theme.base0E}"
        base0F = "#${theme.base0F}"
      '';
      "zed/themes/nc-${theme.slug}.json".source = zedThemeFile;
      "zed/keymap.json" = {
        source = zedKeymapSource;
        type = "copy";
      };
      "zed/settings.json" = {
        source = zedSettingsFile;
        type = "copy";
      };
    };

  };

}
