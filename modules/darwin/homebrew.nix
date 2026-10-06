{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optional;
in
{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = true;
    user = config.nc.user.name;

    # nehir brings its own tap; tap it only when nehir is enabled, or an unused
    # cask-less tap makes `brew cleanup` abort activation on an untrusted cask.
    taps = {
      "abue-ammar/homebrew-tinycast" = inputs.homebrew-tinycast;
      "apple/homebrew-apple" = inputs.homebrew-apple;
      "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "osx-cross/homebrew-arm" = inputs.homebrew-osx-cross-arm;
    }
    // optionalAttrs config.nc.darwin.nehir.enable {
      "guria/homebrew-tap" = inputs.homebrew-guria;
    };

    mutableTaps = false;

    trust.casks = optional config.nc.darwin.nehir.enable "guria/tap/nehir";
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
      "homebrew/cask"
      "homebrew/core"
      "osx-cross/arm"
    ]
    ++ optional config.nc.darwin.nehir.enable "guria/tap";

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
