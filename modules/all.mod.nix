{ ... }:

{
  flake.commonModules = {
    fonts = ./common/fonts.nix;
    home-manager = ./common/home-manager.nix;
    inputs-gcroot = ./common/inputs-gcroot.nix;
    nix = ./common/nix.nix;
    theme = ./theme/default.nix;
    user = ./common/user.nix;

    apps = ./home/apps.nix;
    bat = ./home/bat.nix;
    btop = ./home/btop.nix;
    codex = ./home/codex.nix;
    desktop-theme = ./home/desktop-theme.nix;
    difftastic = ./home/difftastic.nix;
    editor = ./home/editor.nix;
    freecad = ./home/freecad.nix;
    ghostty = ./home/ghostty.nix;
    kitty = ./home/kitty.nix;
    opencode = ./home/opencode.nix;
    packages = ./home/packages.nix;
    prismlauncher = ./home/prismlauncher.nix;
    radicle = ./home/radicle.nix;
    t3-code = ./home/t3-code.nix;
    terminal = ./home/terminal.nix;
    version-control = ./home/version-control.nix;
    watchman = ./home/watchman.nix;
  };

  flake.darwinModules = {
    amp = ./darwin/amp.nix;
    desktop = ./darwin/desktop.nix;
    dock = ./darwin/dock.nix;
    darwin-essentials = ./darwin/essentials.nix;
    finder = ./darwin/finder.nix;
    freecad = ./darwin/freecad.nix;
    homebrew = ./darwin/homebrew.nix;
    karabiner = ./darwin/karabiner.nix;
    login = ./darwin/login.nix;
    menu = ./darwin/menu.nix;
    mullvad-dns = ./darwin/mullvad-dns.nix;
    paneru = ./darwin/paneru.nix;
    paperwm = ./darwin/paperwm.nix;
    screencapture = ./darwin/screencapture.nix;
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
    keycode-remap = ./nixos/keycode-remap.nix;
    mullvad-dns = ./nixos/mullvad-dns.nix;
    nixos = ./nixos/default.nix;
    niri = ./nixos/niri.nix;
    nvidia = ./nixos/nvidia.nix;
    printing = ./nixos/printing.nix;
  };
}
