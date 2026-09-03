{
  config,
  inputs,
  ...
}:

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
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "osx-cross/homebrew-arm" = inputs.homebrew-osx-cross-arm;
    };

    mutableTaps = false;
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
      "codex"
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
