{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    nerd-fonts.lilex
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term-slab
    nerd-fonts.departure-mono
    nerd-fonts.martian-mono
    nerd-fonts.recursive-mono
    nerd-fonts.symbols-only
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
    sketchybar-app-font
  ];
}
