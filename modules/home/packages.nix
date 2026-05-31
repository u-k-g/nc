{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib) optionals;
  piCodingAgent = self.packages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;

  commonPackages = with pkgs; [
    bash
    nushell
    atuin

    coreutils
    diffutils
    openssl
    less
    watch
    rsync
    rclone
    curl
    pkg-config
    cacert

    helix

    git
    jujutsu
    jjui
    radicle-node
    gh
    mergiraf
    difftastic

    tmux
    carapace
    zellij
    btop
    lazygit
    yazi
    lazyssh
    dialog
    fzf
    inshellisense
    hyperfine
    mosh
    dix

    ripgrep
    ast-grep
    gitleaks
    fd
    eza
    zoxide
    unzip
    unar
    just

    sd
    ffmpeg
    ffsend
    scrcpy
    tio
    imagemagick

    bun
    deno
    nodejs
    piCodingAgent
    pnpm
    zig
    lua
    fnm

    llvm
    clang
    rustc
    cargo
    clang-tools
    lld

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
    micropython
    tytools

    arp-scan
    nmap
    nbtscan
    usbutils

    screenfetch
    fastfetch
  ];

  linuxPackages = with pkgs; [
    docker
    docker-buildx
    opencode
    opencode-desktop
  ];

  darwinPackages = with pkgs; [
    colima
  ];
in
{
  home-manager.users.${config.nc.user.name}.home.packages =
    commonPackages
    ++ optionals pkgs.stdenv.isLinux linuxPackages
    ++ optionals pkgs.stdenv.isDarwin darwinPackages;
}
