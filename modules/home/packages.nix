{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  user = config.nc.user;
  workstation = pkgs.stdenv.isDarwin || config.nc.nixos.workstation.enable;

  kicadCli = pkgs.writeShellScriptBin "kicad-cli" ''
    exec /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli "$@"
  '';
  corepackPnpm = pkgs.symlinkJoin {
    name = "corepack-pnpm";
    paths = [ pkgs.corepack ];
    postBuild = ''
      rm -f $out/bin/corepack
      rm -f $out/bin/yarn
    '';
  };

  dix =
    if pkgs.stdenv.isDarwin then
      pkgs.dix.overrideAttrs (_: {
        doCheck = false;
      })
    else
      pkgs.dix;

  essentialPackages = with pkgs; [
    bash
    nushell
    atuin

    coreutils
    diffutils
    openssl
    watch
    rsync
    rclone
    curl
    cacert

    helix

    git
    jujutsu
    jjui
    gh
    mergiraf

    carapace
    btop
    yazi
    dialog
    inshellisense
    fish
    hyperfine
    mosh

    ripgrep
    ast-grep
    fd
    eza
    zoxide
    unzip
    just
    jq

    sd

    arp-scan
    nmap
    nbtscan
    usbutils

    microfetch
    vivid

    pkg-config
    python3

    nodejs
    corepackPnpm
    tio
  ];

  extendedPackages = with pkgs; [
    dix

    ffsend
    handy

    lua

    uv
    nixfmt
    topiary
    shfmt
    shellcheck

    markdown-oxide
    nixd
    taplo
    tree-sitter
    bash-language-server
    typos
    yaml-language-server
  ];

  linuxPackages = with pkgs; [
    docker
    docker-buildx
    kicad
    opencode-desktop
    unar
  ];

  darwinPackages = [
    kicadCli
    pkgs.clang
  ];
in
{
  home.users.${user.name} = {
    packages =
      essentialPackages
      ++ optionals workstation extendedPackages
      ++ optionals (workstation && pkgs.stdenv.isLinux) linuxPackages
      ++ optionals (workstation && pkgs.stdenv.isDarwin) darwinPackages;
  };
}
