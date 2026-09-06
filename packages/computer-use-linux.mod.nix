{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
    in
    {
      packages = optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
        computer-use-linux = pkgs.callPackage (
          {
            autoPatchelfHook,
            fetchurl,
            lib,
            stdenv,
            ...
          }:
          let
            inherit (lib.lists) singleton;
          in
          stdenv.mkDerivation (finalAttrs: {
            pname = "computer-use-linux";
            version = "0.5.0";

            src = fetchurl {
              url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-x86_64-unknown-linux-gnu";
              hash = "sha256-0h55gzb1xrae98hTKIZjmVD+JIVeLbsgXMPzRSiUAg4=";
            };
            cosmic = fetchurl {
              url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-cosmic-x86_64-unknown-linux-gnu";
              hash = "sha256-wet2Dul9UNwVfWcRlWzYT5dwHJmIVbI8HvG9d2GaFFg=";
            };

            dontUnpack = true;
            nativeBuildInputs = singleton autoPatchelfHook;
            buildInputs = singleton stdenv.cc.cc.lib;
            installPhase = ''
              runHook preInstall
              install -Dm755 "$src" "$out/bin/computer-use-linux"
              install -Dm755 "$cosmic" "$out/bin/computer-use-linux-cosmic"
              runHook postInstall
            '';

            meta = {
              description = "Linux desktop MCP server and COSMIC window helper";
              homepage = "https://github.com/agent-sh/computer-use-linux";
              license = lib.licenses.mit;
              platforms = singleton "x86_64-linux";
              mainProgram = "computer-use-linux";
            };
          })
        ) { };
      };
    };
}
