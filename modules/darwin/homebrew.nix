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
      "apple/homebrew-apple" = inputs.homebrew-apple;
      "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "manaflow-ai/homebrew-cmux" = inputs.homebrew-cmux;
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
      "apple/apple"
      "felixkratz/formulae"
      "homebrew/cask"
      "homebrew/core"
      "manaflow-ai/cmux"
      "osx-cross/arm"
    ];

    brews = [
      "colima"
      "create-dmg"
      "espeak-ng"
      "glslviewer"
      "mas"
      "ruby"
      "sk"
      "unar"
      "felixkratz/formulae/borders"
      {
        name = "felixkratz/formulae/sketchybar";
        start_service = true;
      }
      "osx-cross/arm/arm-gcc-bin@10"
    ];

    casks = [
      "battery"
      "blip"
      "cmux"
      "codex"
      "font-sketchybar-app-font"
      "hammerspoon"
      "helium-browser"
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
