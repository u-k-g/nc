{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.lists) optionals;
  workstation = pkgs.stdenv.isDarwin || config.nc.nixos.workstation.enable;
in
{
  fonts.packages =
    with pkgs;
    [
      nerd-fonts.iosevka
      inter
    ]
    ++ optionals workstation [
      nerd-fonts.jetbrains-mono
      nerd-fonts.monaspace
      nerd-fonts.lilex
      nerd-fonts.iosevka-term-slab
      nerd-fonts.departure-mono
      nerd-fonts.martian-mono
      nerd-fonts.recursive-mono
      nerd-fonts.symbols-only
      self.packages.${pkgs.stdenv.hostPlatform.system}.instrument-serif
      ibm-plex
      fraunces
      lora
      texlivePackages.cormorantgaramond
      texlivePackages.spectral
      alegreya
      junicode
      prociono
      oldstandard
      recursive
    ];
}
