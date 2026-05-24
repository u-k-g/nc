{ ... }:

{
  flake.commonModules = {
    apps = ./apps.nix;
    editor = ./editor.nix;
    home = ./home/default.nix;
    inputs-gcroot = ./inputs-gcroot.nix;
    nix = ./nix.nix;
    packages = ./packages.nix;
    shell = ./shell.nix;
    terminal = ./terminal.nix;
    theme = ./theme.nix;
    user = ./user.nix;
    version-control = ./version-control.nix;
  };

  flake.darwinModules = {
    darwin-desktop = ./darwin-desktop.nix;
    fonts = ./fonts.nix;
    homebrew = ./homebrew.nix;
  };

  flake.nixosModules = {
    nixos = ./nixos.nix;
  };
}
