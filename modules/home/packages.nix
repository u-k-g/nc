{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  user = config.nc.user;
  edgePkgs = inputs.edge.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;

  kicadCli = pkgs.writeShellScriptBin "kicad-cli" ''
    exec /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli "$@"
  '';
  dix =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.dix.overrideAttrs (_: {
        doCheck = false;
      })
    else
      pkgs.dix;

  # Node ships with an npm whose global prefix is the read-only Nix store, so
  # `npm install -g` fails. Shadow the binary with hiPrio so every caller,
  # scripts included, lands on pnpm instead; `npx` maps to `pnpm dlx`. pnpm
  # is not a drop-in clone: it has no `npm ci`, and it skips dependency build
  # scripts that are not allowed, with a warning.
  npmIsPnpm = lib.hiPrio (pkgs.writeShellScriptBin "npm" ''
    exec pnpm "$@"
  '');
  npxIsPnpm = lib.hiPrio (pkgs.writeShellScriptBin "npx" ''
    exec pnpm dlx "$@"
  '');

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
    uv

    nodejs
    npmIsPnpm
    npxIsPnpm
    # nixpkgs' pnpm 11 ignores minimumReleaseAgeExclude; edge tracks pnpm 12,
    # which resolves browse to the newest release as the pnpm config declares.
    edgePkgs.pnpm
    tio
  ];

  extendedPackages = with pkgs; [
    dix

    ffsend

    lua

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
    unar
  ];

  darwinPackages = [
    kicadCli
    pkgs.clang
  ];
in
{
  home.users.${user.name} = {
    xdg.config.files."pnpm/config.yaml" = {
      generator = (pkgs.formats.yaml { }).generate "pnpm-config.yaml";
      value.minimumReleaseAge = 72 * 60;
      # browse ships fresh releases and prebuilt platform binaries that pnpm
      # resolves alongside it, so both need to skip the release-age guard.
      value.minimumReleaseAgeExclude = [ "@opencode/browse*" ];
    };

    packages =
      essentialPackages
      ++ optionals workstation extendedPackages
      ++ optionals (workstation && pkgs.stdenv.hostPlatform.isLinux) linuxPackages
      ++ optionals (workstation && pkgs.stdenv.hostPlatform.isDarwin) darwinPackages;
  };
}
