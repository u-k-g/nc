{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.instrument-serif = pkgs.callPackage (
        {
          fetchFromGitHub,
          lib,
          stdenvNoCC,
        }:
        stdenvNoCC.mkDerivation {
          pname = "instrument-serif";
          version = "2023-04-26";

          src = fetchFromGitHub {
            owner = "Instrument";
            repo = "instrument-serif";
            rev = "65c0ef225f386a3c7e87570a4aa9cc0262c2fd81";
            hash = "sha256-8T857KyE+s78wSx+Piker50lMiI7GcQa7vW/9L96zXo=";
          };

          installPhase = ''
            runHook preInstall

            install -Dm644 fonts/otf/*.otf -t "$out/share/fonts/opentype"

            runHook postInstall
          '';

          meta = {
            description = "Condensed display serif designed for the Instrument brand";
            homepage = "https://github.com/Instrument/instrument-serif";
            license = lib.licenses.ofl;
            platforms = lib.platforms.all;
          };
        }
      ) { };
    };
}
