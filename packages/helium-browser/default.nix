{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "helium-browser";
  version = "0.12.5.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-uUZauNralX6katmnO9VDLEs+d+HIhkjkeV36Dw2eUmM=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${appimageTools.extract { inherit pname version src; }}/helium.desktop \
      "$out/share/applications/helium.desktop"
    sed -i \
      -e "s|^Exec=helium %U$|Exec=$out/bin/helium-browser %U|" \
      -e "s|^Exec=helium$|Exec=$out/bin/helium-browser|" \
      "$out/share/applications/helium.desktop"
  '';

  meta = {
    description = "Helium browser";
    homepage = "https://github.com/imputnet/helium-linux";
    license = lib.licenses.bsd3;
    mainProgram = "helium-browser";
    platforms = [ "x86_64-linux" ];
  };
}
