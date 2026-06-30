{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:

let
  inherit (lib.lists) singleton;

  version = "0.0.29-nightly.20260630.695";
in
stdenvNoCC.mkDerivation {
  pname = "t3-code-nightly";
  inherit version;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.zip";
    hash = "sha256-lOEbWW4XktykM72hC2BtrRIsv0d9c2TIw1xXp0f3xIA=";
  };

  nativeBuildInputs = singleton unzip;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R *.app "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "T3 Code nightly editor";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    platforms = singleton "aarch64-darwin";
  };
}
