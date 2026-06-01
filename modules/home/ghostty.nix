{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) optionalString;
  user = config.nc.user;
  theme = config.nc.theme;
  dotfiles = ../../dotfiles;
  ghosttyConfig = pkgs.runCommand "ghostty-config" { } ''
    cp -R ${dotfiles + /config/ghostty} $out
    chmod -R u+w $out
    mkdir -p $out/themes
    cat > $out/themes/nc <<'EOF'
    ${config.nc.theme.ghosttyConfig}
    EOF
    cat >> $out/config <<'EOF'

    # Managed by Nix.
    font-size = ${toString theme.font.size.normal}
    font-family = ${theme.font.mono.name}
    window-padding-x = ${toString theme.padding}
    window-padding-y = ${toString theme.padding}
    scrollback-limit = ${toString (100 * 1024 * 1024)}
    mouse-hide-while-typing = true
    confirm-close-surface = false
    quit-after-last-window-closed = true
    config-file = ${pkgs.writeText "base16-config" theme.ghosttyConfig}
    EOF
  '';
in
{
  home-manager.users.${user.name} = {
    xdg.configFile."ghostty".source = ghosttyConfig;
    xdg.configFile."xdg-terminals.list" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      text = "com.mitchellh.ghostty.desktop\n";
    };
  };
}
