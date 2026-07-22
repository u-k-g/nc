{
  kopuz,
  lib,
  symlinkJoin,
}:

let
  inherit (lib.lists) singleton;
in
symlinkJoin {
  name = "kopuz-${kopuz.version}";
  paths = singleton kopuz;

  postBuild = ''
    mkdir -p "$out/Applications"
    ln -s ../bin/kopuz.app "$out/Applications/Kopuz.app"
  '';

  meta = kopuz.meta // {
    mainProgram = "kopuz";
  };
}
