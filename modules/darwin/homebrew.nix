{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib.lists) singleton;
in
{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = true;
    user = config.nc.user.name;

    taps = {
      "abue-ammar/homebrew-tinycast" = inputs.homebrew-tinycast;
      "apple/homebrew-apple" = inputs.homebrew-apple;
      "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
      "guria/homebrew-tap" = inputs.homebrew-guria;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "osx-cross/homebrew-arm" = inputs.homebrew-osx-cross-arm;
    };

    mutableTaps = false;

    trust.casks = singleton "guria/tap/nehir";

    # Homebrew resolves its tap-trust store via $XDG_CONFIG_HOME, but activation
    # runs brew with a cleared env, so pin it or `brew trust` no-ops and
    # `brew cleanup` aborts activation on the untrusted guria tap.
    extraEnv.XDG_CONFIG_HOME = "${config.nc.user.homeDirectory}/.config";
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      cleanup = "uninstall";
      upgrade = true;
    };

    taps = [
      "abue-ammar/tinycast"
      "apple/apple"
      "felixkratz/formulae"
      "guria/tap"
      "homebrew/cask"
      "homebrew/core"
      "osx-cross/arm"
    ];

    brews = [
      "colima"
      "create-dmg"
      "espeak-ng"
      "glslviewer"
      "mas"
      "ruby"
      "unar"
      "felixkratz/formulae/borders"
      {
        name = "felixkratz/formulae/sketchybar";
        start_service = true;
      }
      "osx-cross/arm/arm-gcc-bin@10"
    ];

    casks = [
      "abue-ammar/tinycast/tinycast@beta"
      "battery"
      "blip"
      "font-sketchybar-app-font"
      "hammerspoon"
      "karabiner-elements"
      "kicad"
      "orcaslicer"
      "sf-symbols"
      "thaw"
      "vesktop"
      "zed"
      "zulu@17"
    ];

    masApps = { };
  };
}
