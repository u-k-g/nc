{ config, inputs, ... }:

{
  nix-homebrew = {
    enable = true;
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
      "felixkratz/formulae"
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
      "freecad"
      "ghostty"
      "hammerspoon"
      "helium-browser"
      "kicad"
      "kitty@nightly"
      "legcord"
      "obsidian"
      "opencode-desktop"
      "orcaslicer"
      "protonvpn"
      "sf-symbols"
      "t3-code@nightly"
      "thaw"
      "zed"
      "zed@preview"
      "zen"
      "zulu@17"
    ];

    masApps = {
      "Command X" = 6448461551;
      "CrystalFetch" = 6454431289;
      "Developer" = 640199958;
      "Flip Clock" = 1553591814;
      "Horo" = 1437226581;
      "Icon Preview" = 6480373509;
      "Keynote" = 409183694;
      "LocalSend" = 1661733229;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "QuickDrop" = 6740147178;
      "Simplenote" = 692867256;
      "Xcode" = 497799835;
    };
  };
}
