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

    tmux
    carapace
    btop
    yazi
    lazyssh
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
    ffmpeg
    imagemagick

    arp-scan
    nmap
    nbtscan
    usbutils

    microfetch
    vivid

    gcc
    gnumake
    pkg-config
    python3

    nodejs
    deno
    corepackPnpm
    tio
  ];

  extendedPackages = with pkgs; [
    zellij
    dix

    gitleaks

    ffsend
    handy
    scrcpy

    zig
    lua

    llvm
    clang
    clang-tools
    lld

    cargo-deny
    cargo-expand
    cargo-fuzz
    cargo-nextest
    evcxr
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt

    cmakeCurses

    ruff
    uv
    biome
    oxlint
    nixfmt
    topiary
    shfmt
    shellcheck

    cmake-language-server
    markdown-oxide
    nixd
    taplo
    texlab
    tree-sitter
    bash-language-server
    ty
    typos
    yaml-language-server
    zls

    arduino-cli
    platformio
    arduino-language-server
    tytools
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
