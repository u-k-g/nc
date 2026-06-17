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
      "barutsrb/homebrew-tap" = inputs.homebrew-barutsrb-tap;
      "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz-formulae;
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-services" = inputs.homebrew-services;
      "manaflow-ai/homebrew-cmux" = inputs.homebrew-manaflow-cmux;
      "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko-tap;
      "osx-cross/homebrew-arm" = inputs.homebrew-osx-cross-arm;
    };

    mutableTaps = false;
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
      "ruby"
      "felixkratz/formulae/borders"
      "felixkratz/formulae/sketchybar"
      "osx-cross/arm/arm-gcc-bin@10"
    ];

    casks = [
      "battery"
      "blip"
      "cmux"
      "font-sketchybar-app-font"
      "hammerspoon"
      "helium-browser"
      "karabiner-elements"
      "kicad"
      "orcaslicer"
      "sf-symbols"
      "thaw"
      "vesktop"
      "zed@preview"
      "zulu@17"
    ];

    masApps = { };
  };
}
