{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  ghosttyConfig = pkgs.runCommand "ghostty-config" { } ''
    cp -R ${dotfiles + /config/ghostty} $out
    chmod -R u+w $out
    mkdir -p $out/themes
    cat > $out/themes/nc <<'EOF'
    ${config.nc.theme.ghosttyConfig}
    EOF
  '';
in
{
  home-manager.users.${user.name}.xdg.configFile."ghostty".source = ghosttyConfig;
}
