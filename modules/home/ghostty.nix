{ config, pkgs, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  shellCommand =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/etc/profiles/per-user/${user.name}/bin/nu --login --env-config ${user.homeDirectory}/.config/nushell/env.nu --config ${user.homeDirectory}/.config/nushell/config.nu"
    else
      "${user.homeDirectory}/.nix-profile/bin/nu --login --env-config ${user.homeDirectory}/.config/nushell/env.nu --config ${user.homeDirectory}/.config/nushell/config.nu";
  ghosttyConfig = pkgs.runCommand "ghostty-config" { } ''
    cp -R ${dotfiles + /config/ghostty} $out
    chmod -R u+w $out
    substituteInPlace $out/config \
      --replace-fail @nushellCommand@ "${shellCommand}"
    mkdir -p $out/themes
    cat > $out/themes/nc <<'EOF'
    ${config.nc.theme.ghosttyConfig}
    EOF
  '';
in
{
  home-manager.users.${user.name}.xdg.configFile."ghostty".source = ghosttyConfig;
}
