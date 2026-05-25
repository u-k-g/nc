{ ... }:

{
  flake.commonModules = {
    apps = ./apps.nix;
    editor = ./editor.nix;
    fonts = ./fonts.nix;
    ghostty = ./ghostty.nix;
    home = ./home/default.nix;
    inputs-gcroot = ./inputs-gcroot.nix;
    nix = ./nix.nix;
    packages = ./packages.nix;
    shell = ./shell.nix;
    terminal = ./terminal.nix;
    theme = ./theme.nix;
    user = ./user.nix;
    version-control = ./version-control.nix;
    secrets = ./secrets.nix;
  };

  flake.darwinModules = {
    darwin-desktop = ./darwin-desktop.nix;
    darwin-defaults = ./darwin-defaults.nix;
    fonts = ./darwin-fonts.nix;
    homebrew = ./homebrew.nix;
    paperwm = ./paperwm.nix;
    secrets = ./secrets-darwin.nix;
    sudo = ./sudo.nix;
  };

  flake.homeModules = {
    base = ./home/base.nix;
  };

  flake.nixosModules = {
    nixos = ./nixos.nix;
    secrets = ./secrets-nixos.nix;
  };
}
