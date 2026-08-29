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
  dotfiles = ../../dotfiles;
  sketchybarConfig = pkgs.callPackage (
    { runCommand }:
    runCommand "sketchybar-config-${theme.slug}" { } ''
      cp --recursive ${dotfiles + /config/sketchybar} $out
      chmod --recursive u+w $out
      CONFIG_DIR=$out ${getExe pkgs.nushell} --no-config-file \
        $out/plugins/icon_map.nu --dump \
        > $out/icon_map.nuon
      mv $out/icon_map.nuon $out/plugins/icon_map.nuon
      substituteInPlace \
        $out/sketchybarrc.nu \
        --replace-fail '@base00@' '${theme.base00}' \
        --replace-fail '@base05@' '${theme.base05}'
      substituteInPlace \
        $out/plugins/paneru_windows.nu \
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
  launchd.user.agents."sketchybar.status".serviceConfig = {
    ProgramArguments = [
      (getExe pkgs.nushell)
      "--no-config-file"
      "${sketchybarConfig}/plugins/clock.nu"
    ];
    EnvironmentVariables = {
      CONFIG_DIR = "${sketchybarConfig}";
      DNS_COMMAND = "/run/current-system/sw/bin/dns";
      HOME = user.homeDirectory;
      SKETCHYBAR = "/opt/homebrew/bin/sketchybar";
    };
    KeepAlive = true;
    ProcessType = "Interactive";
    RunAtLoad = true;
  };

  system.defaults.NSGlobalDomain = {
    AppleIconAppearanceTheme = if theme.isDark then "RegularDark" else null;
    AppleInterfaceStyle = if theme.isDark then "Dark" else null;
    AppleInterfaceStyleSwitchesAutomatically = false;
  };

  home.users.${user.name} = {
    xdg.config.files = {
      "sketchybar".source = sketchybarConfig;
    };
  };
}
