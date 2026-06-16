{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:

let
  version = "0.0.27";
in
stdenvNoCC.mkDerivation {
  pname = "t3-code-nightly";
  inherit version;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.zip";
    hash = "sha256-2teOphbCdl1mQHFvDUK+qVdBdwHD/9uu/lY4VmRf1hU=";
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
