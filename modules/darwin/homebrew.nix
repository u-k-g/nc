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
      "freecad/homebrew-freecad" = inputs.homebrew-freecad;
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
      # sudo drops the shell's XDG setting. Bundle can inspect dependencies
      # before applying Brewfile trust, so use the same existing trust store.
      extraEnv.XDG_CONFIG_HOME = "${config.nc.user.homeDirectory}/.config";
    };

    taps = [
      "abue-ammar/tinycast"
      "apple/apple"
      "felixkratz/formulae"
      {
        name = "freecad/freecad";
        # Activation may use a different trust store than the interactive shell.
        trusted = true;
      }
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

      # Anthracite: macOS dependencies of freecad@1.1.3_py313_qt6, not FreeCAD itself.
      # Declare these explicitly so activation cleanup retains the development libs.
      "boost"
      "cmake"
      "cups"
      "cython"
      "doxygen"
      "expat"
      "flann"
      "fmt"
      "freecad/freecad/calculix@2.23"
      "freecad/freecad/coin3d@4.0.8_py313_qt6"
      "freecad/freecad/fc_bundle_py313_qt6"
      "freecad/freecad/med-file@5.0.0_py313"
      "freecad/freecad/netgen@6.2.2601"
      "freecad/freecad/pyside6_py313"
      "freecad/freecad/vtk@9.5.2_py313"
      "freeimage"
      "freetype"
      "gcc"
      "glew"
      "hdf5"
      "icu4c"
      "icu4c@78"
      "libaec"
      "libomp"
      "ninja"
      "nlohmann-json"
      "numpy"
      "opencascade"
      "orocos-kdl"
      "pcl"
      "pkg-config"
      "pybind11"
      "python@3.13"
      "qt"
      "qtbase"
      "qtsvg"
      "qttools"
      "swig"
      "tbb"
      "vtk"
      "vulkan-headers"
      "webp"
      "xerces-c"
      "yaml-cpp"
      "zlib-ng-compat"
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
