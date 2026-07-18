{
  lib,
  stdenvNoCC,
  t3CodeNightly,
  unzip,
}:

let
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.lists) filter head singleton;
  inherit (lib.strings) hasSuffix removePrefix removeSuffix;

  archive =
    head <| filter (path: hasSuffix "-arm64.zip" <| toString path) <| listFilesRecursive t3CodeNightly;
  version = removeSuffix "-arm64.zip" <| removePrefix "T3-Code-" <| baseNameOf archive;
in
stdenvNoCC.mkDerivation {
  pname = "t3-code-nightly";
  inherit version;

  src = archive;

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
