{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib.modules) mkBefore;
  inherit (lib.strings) escapeShellArg;
in

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

  system.activationScripts.homebrew.text = mkBefore ''
    # Homebrew 6 requires explicit trust for formulae from non-official taps.
    if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
      echo >&2 "trusting Homebrew tap formulae..."
      PATH="${config.homebrew.prefix}/bin:$PATH" \
      sudo \
        --preserve-env=PATH \
        --user=${escapeShellArg config.homebrew.user} \
        --set-home \
        brew trust --formula \
          felixkratz/formulae/borders \
          felixkratz/formulae/sketchybar \
          osx-cross/arm/arm-gcc-bin@10
    fi
  '';
}
