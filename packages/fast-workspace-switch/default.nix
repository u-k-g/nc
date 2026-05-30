{ stdenv, swift }:

stdenv.mkDerivation {
  pname = "fast-workspace-switch";
  version = "0-unstable";

  src = ./fast-workspace-switch.swift;
  dontUnpack = true;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc \
      -framework CoreGraphics \
      -framework Foundation \
      -F/System/Library/PrivateFrameworks \
      -framework SkyLight \
      "$src" \
      -o fast-workspace-switch
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 fast-workspace-switch "$out/bin/fast-workspace-switch"
    runHook postInstall
  '';
}
