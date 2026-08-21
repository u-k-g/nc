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
  launchd.user.agents."sketchybar.paneru-windows".serviceConfig = {
    ProgramArguments = [
      "${sketchybarConfig}/plugins/paneru_windows.nu"
    ];
    EnvironmentVariables = {
      CONFIG_DIR = "${sketchybarConfig}";
      HOME = user.homeDirectory;
      PANERU = "/etc/profiles/per-user/${user.name}/bin/paneru";
      SKETCHYBAR = "/opt/homebrew/bin/sketchybar";
    };
    KeepAlive = true;
    ProcessType = "Background";
    RunAtLoad = true;
  };

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
