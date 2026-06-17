{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:

let
  version = "0.0.28-nightly.20260617.578";
in
stdenvNoCC.mkDerivation {
  pname = "t3-code-nightly";
  inherit version;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.zip";
    hash = "sha256-4G2JiHwOBOmZIbtUPtXRJUrs1tzb1WIMHOnqyAy9ssw=";
  };

  nativeBuildInputs = [ unzip ];

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
    platforms = [ "aarch64-darwin" ];
  };
}
