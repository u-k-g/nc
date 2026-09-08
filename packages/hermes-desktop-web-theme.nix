{
  lib,
  runCommand,
  writeText,
  fontconfig,
  python3,
  imagemagick,
  theme,
  src,
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.generators) toJSON;
  inherit (lib.strings) escapeXML;
  palette = genAttrs [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ] (name: "#${theme.${name}}");
in
runCommand "hermes-web-theme"
  {
    nativeBuildInputs = [
      fontconfig
      imagemagick
      (python3.withPackages (ps: [
        ps.fonttools
        ps.brotli
      ]))
    ];
    FONTCONFIG_FILE = writeText "hermes-web-fonts.conf" ''
      <?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <dir>${escapeXML "${theme.font.sans.package}/share/fonts"}</dir>
        <dir>${escapeXML "${theme.font.mono.package}/share/fonts"}</dir>
        <cachedir>/tmp/hermes-web-font-cache</cachedir>
      </fontconfig>
    '';
  }
  /* bash */ ''
    mkdir -p "$out"
    cp ${
      writeText "hermes-web-theme.json" (
        toJSON { } {
          version = 1;
          mode = if theme.isDark then "dark" else "light";
          inherit palette;
          fonts = {
            sans = "/theme/sans.woff2";
            mono = "/theme/mono.woff2";
          };
        }
      )
    } "$out/config.json"
    python ${
      writeText "hermes-web-fonts.py" /* python */ ''
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
            font.save(os.path.join(os.environ['out'], kind + '.woff2'))
      ''
    }
    cp ${
      writeText "hermes-web-manifest.json" (
        toJSON { } {
          id = "/";
          name = "Hermes · Manara";
          short_name = "Hermes";
          start_url = "/";
          scope = "/";
          display = "standalone";
          background_color = palette.base00;
          theme_color = palette.base00;
          icons = [
            {
              src = "/pwa-192.png";
              sizes = "192x192";
              type = "image/png";
              purpose = "any";
            }
            {
              src = "/pwa-512.png";
              sizes = "512x512";
              type = "image/png";
              purpose = "any";
            }
            {
              src = "/theme/pwa-maskable.png";
              sizes = "512x512";
              type = "image/png";
              purpose = "maskable";
            }
          ];
        }
      )
    } "$out/manifest.webmanifest"
    magick ${src}/vendor/hermes-desktop/assets/icon.png -resize 320x320 \
      -background '${palette.base00}' -gravity center -extent 512x512 "$out/pwa-maskable.png"
  ''
