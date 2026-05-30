{ ... }:

{
  flake.commonModules = {
    fonts = ./common/fonts.nix;
    home-manager = ./common/home-manager.nix;
    inputs-gcroot = ./common/inputs-gcroot.nix;
    nix = ./common/nix.nix;
    secrets = ./secrets/default.nix;
    theme = ./theme/default.nix;
    user = ./common/user.nix;

    apps = ./home/apps.nix;
    editor = ./home/editor.nix;
    ghostty = ./home/ghostty.nix;
    packages = ./home/packages.nix;
    shell = ./home/shell.nix;
    terminal = ./home/terminal.nix;
    version-control = ./home/version-control.nix;
  };

  flake.darwinModules = {
    desktop = ./darwin/desktop.nix;
    dock = ./darwin/dock.nix;
    essentials = ./darwin/essentials.nix;
    finder = ./darwin/finder.nix;
    homebrew = ./darwin/homebrew.nix;
    karabiner = ./darwin/karabiner.nix;
    login = ./darwin/login.nix;
    menu = ./darwin/menu.nix;
    paneru = ./darwin/paneru.nix;
    paperwm = ./darwin/paperwm.nix;
    screencapture = ./darwin/screencapture.nix;
    skhd = ./darwin/skhd.nix;
    secrets = ./secrets/darwin.nix;
    sudo = ./darwin/sudo.nix;
    trackpad = ./darwin/trackpad.nix;
  };

  flake.homeModules = {
    base = ./home/base.nix;
  };

  flake.nixosModules = {
    audio = ./nixos/audio.nix;
    bluetooth = ./nixos/bluetooth.nix;
    desktop = ./nixos/desktop.nix;
    gaming = ./nixos/gaming.nix;
    graphics = ./nixos/graphics.nix;
    nixos = ./nixos/default.nix;
    niri = ./nixos/niri.nix;
    nvidia = ./nixos/nvidia.nix;
    printing = ./nixos/printing.nix;
    secrets = ./secrets/nixos.nix;
  };
}
