{
  config,
  pkgs,
  ...
}:

let
  user = config.nc.user;
  theme = config.nc.theme;
  dotfiles = ../../dotfiles;
  sketchybarConfig = pkgs.callPackage (
    { runCommand }:
    runCommand "sketchybar-config-${theme.slug}" { } ''
      cp --recursive ${dotfiles + /config/sketchybar} $out
      chmod --recursive u+w $out
      substituteInPlace \
        $out/sketchybarrc.nu \
        --replace-fail '@base00@' '${theme.base00}' \
        --replace-fail '@base03@' '${theme.base03}' \
        --replace-fail '@base05@' '${theme.base05}'
      substituteInPlace \
        $out/plugins/paneru_windows.nu \
        --replace-fail '@base03@' '${theme.base03}' \
        --replace-fail '@base05@' '${theme.base05}'
      substituteInPlace \
        $out/plugins/timer.nu \
        --replace-fail '@base04@' '${theme.base04}' \
        --replace-fail '@base05@' '${theme.base05}' \
        --replace-fail '@base08@' '${theme.base08}'
    ''
  ) { };
in
{
  system.defaults.NSGlobalDomain = {
    AppleIconAppearanceTheme = if theme.isDark then "RegularDark" else null;
    AppleInterfaceStyle = if theme.isDark then "Dark" else null;
    AppleInterfaceStyleSwitchesAutomatically = false;
  };

  home-manager.users.${user.name} = {
    xdg.configFile = {
      "sketchybar".source = sketchybarConfig;
    };
  };
}
