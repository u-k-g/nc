{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../dotfiles;
  ghosttyConfig = pkgs.runCommand "ghostty-config" { } ''
    cp -R ${dotfiles + /config/ghostty} $out
    chmod -R u+w $out
    substituteInPlace $out/config \
      --replace-fail @nushellCommand@ "/etc/profiles/per-user/${user.name}/bin/nu --login --env-config ${user.homeDirectory}/.config/nushell/env.nu --config ${user.homeDirectory}/.config/nushell/config.nu"
    mkdir -p $out/themes
    cat > $out/themes/nc <<'EOF'
    ${config.nc.theme.ghosttyConfig}
    EOF
  '';
in
{
  home-manager.users.${user.name}.xdg.configFile = {
    "ghostty".source = ghosttyConfig;
    "hammerspoon".source = dotfiles + /config/hammerspoon;
    "paperwm".source = dotfiles + /config/paperwm;
    "sketchybar".source = dotfiles + /config/sketchybar;
  };
}
