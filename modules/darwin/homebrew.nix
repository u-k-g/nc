{ config, inputs, ... }:

{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = true;
    user = config.nc.user.name;

    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };

    mutableTaps = true;
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    taps = [
      "apple/apple"
      "barutsrb/tap"
      "felixkratz/formulae"
      "homebrew/cask"
      "homebrew/services"
      "manaflow-ai/cmux"
      "nikitabobko/tap"
      "osx-cross/arm"
    ];

    brews = [
      "create-dmg"
      "espeak-ng"
      "glslviewer"
      "mas"
      "opencode"
      "ruby"
      "felixkratz/formulae/borders"
      "felixkratz/formulae/sketchybar"
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
      "omniwm"
      "opencode-desktop"
      "sf-symbols"
      "t3-code@nightly"
      "thaw"
      "vesktop"
      "zed@preview"
      "zulu@17"
    ];

    masApps = { };
  };
}
