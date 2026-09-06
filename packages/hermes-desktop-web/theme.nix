{
  lib,
  runCommand,
  writeText,
  fontconfig,
  python3,
  theme,
}:
let
  inherit (lib.generators) toJSON;
  inherit (lib.strings) escapeXML;
  colors = {
    background = "#${theme.base00}";
    foreground = "#${theme.base05}";
    card = "#${theme.base01}";
    cardForeground = "#${theme.base05}";
    muted = "#${theme.base02}";
    mutedForeground = "#${theme.base04}";
    popover = "#${theme.base01}";
    popoverForeground = "#${theme.base05}";
    primary = "#${theme.base0D}";
    primaryForeground = "#${theme.base00}";
    secondary = "#${theme.base02}";
    secondaryForeground = "#${theme.base05}";
    accent = "#${theme.base02}";
    accentForeground = "#${theme.base05}";
    border = "#${theme.base02}";
    input = "#${theme.base03}";
    ring = "#${theme.base0D}";
    midground = "#${theme.base0C}";
    destructive = "#${theme.base08}";
    destructiveForeground = "#${theme.base00}";
    sidebarBackground = "#${theme.base01}";
    userBubble = "#${theme.base02}";
  };
  mode = if theme.isDark then "dark" else "light";
  desktopTheme = {
    name = "nc";
    label = "nc";
    description = "Declared by Manara's Nix configuration";
    inherit colors;
    # Both variants preserve the declared palette; no synthesized light colors.
    darkColors = colors;
    terminal = {
      foreground = "#${theme.base05}";
      cursor = "#${theme.base05}";
      selectionBackground = "#${theme.base02}";
      black = "#${theme.base00}";
      red = "#${theme.base08}";
      green = "#${theme.base0B}";
      yellow = "#${theme.base0A}";
      blue = "#${theme.base0D}";
      magenta = "#${theme.base0E}";
      cyan = "#${theme.base0C}";
      white = "#${theme.base05}";
      brightBlack = "#${theme.base03}";
      brightRed = "#${theme.base08}";
      brightGreen = "#${theme.base0B}";
      brightYellow = "#${theme.base0A}";
      brightBlue = "#${theme.base0D}";
      brightMagenta = "#${theme.base0E}";
      brightCyan = "#${theme.base0C}";
      brightWhite = "#${theme.base07}";
    };
    typography = {
      fontSans = "\"${theme.font.sans.name}\", sans-serif";
      fontMono = "\"${theme.font.mono.name}\", monospace";
      fontUrl = "";
    };
  };
in
runCommand "hermes-themenix"
  {
    nativeBuildInputs = [
      fontconfig
      (python3.withPackages (ps: [
        ps.fonttools
        ps.brotli
      ]))
    ];
    FONTCONFIG_FILE = writeText "hermes-fonts.conf" ''
      <?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <dir>${escapeXML "${theme.font.sans.package}/share/fonts"}</dir>
        <dir>${escapeXML "${theme.font.mono.package}/share/fonts"}</dir>
        <cachedir>/tmp/hermes-font-cache</cachedir>
      </fontconfig>
    '';
  }
  /* bash */ ''
    mkdir -p "$out"
    cp ${writeText "themenix.ts" "export const themenixTheme = ${toJSON { } desktopTheme};\n"} "$out/themenix.ts"
    cp ${
      writeText "themenix.css" /* css */ ''
        @font-face { font-family: "${theme.font.sans.name}"; src: url('./themenix-sans.woff2') format('woff2'); font-weight: 400; font-display: swap; }
        @font-face { font-family: "${theme.font.mono.name}"; src: url('./themenix-mono.woff2') format('woff2'); font-weight: 400; font-display: swap; }
      ''
    } "$out/themenix.css"
    python ${
      writeText "hermes-fonts.py" /* python */ ''
        import os, subprocess
        from fontTools.ttLib import TTFont
        for kind, family in ${
          toJSON { } {
            sans = theme.font.sans.name;
            mono = theme.font.mono.name;
          }
        }.items():
            source = subprocess.check_output(['fc-match', '--format=%{file}', family + ':style=Regular'], text=True)
            font = TTFont(source)
            font.flavor = 'woff2'
            font.save(os.path.join(os.environ['out'], 'themenix-' + kind + '.woff2'))
      ''
    }
    cp ${
      writeText "themenix-boot.html" /* html */ ''
        <style>html { background: ${colors.background}; color: ${colors.foreground}; color-scheme: ${mode}; }</style>
        <script>
          // Paint the declaration even when a browser has cached an older theme.
          document.documentElement.style.backgroundColor = '${colors.background}';
          document.documentElement.style.colorScheme = '${mode}';
          try {
            localStorage.setItem('hermes-boot-background', '${colors.background}');
            localStorage.setItem('hermes-boot-color-scheme', '${mode}');
          } catch { /* Storage is optional. */ }
        </script>
      ''
    } "$out/boot.html"
  ''
