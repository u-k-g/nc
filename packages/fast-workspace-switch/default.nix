{
  stdenv,
  swift,
  writeText,
}:

stdenv.mkDerivation {
  pname = "fast-workspace-switch";
  version = "0-unstable";

  src = writeText "skylight-shim.h" ''
    #ifndef NC_SKYLIGHT_SHIM_H
    #define NC_SKYLIGHT_SHIM_H

    #include <CoreFoundation/CoreFoundation.h>
    #include <stdint.h>

    extern CFArrayRef CGSCopyManagedDisplaySpaces(int32_t connection);
    extern uint64_t CGSGetActiveSpace(int32_t connection);
    extern int32_t SLSMainConnectionID(void);

    static inline CFArrayRef NCCopyManagedDisplaySpaces(void) {
      return CGSCopyManagedDisplaySpaces(SLSMainConnectionID());
    }

    static inline uint64_t NCGetActiveSpace(void) {
      return CGSGetActiveSpace(SLSMainConnectionID());
    }

    #endif
  '';
  swiftSource = ./fast-workspace-switch.swift;
  dontUnpack = true;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc \
      -import-objc-header "$src" \
      -framework CoreGraphics \
      -framework Foundation \
      -F/System/Library/PrivateFrameworks \
      -framework SkyLight \
      "$swiftSource" \
      -o fast-workspace-switch
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 fast-workspace-switch "$out/bin/fast-workspace-switch"
    runHook postInstall
  '';

  meta.mainProgram = "fast-workspace-switch";
}
