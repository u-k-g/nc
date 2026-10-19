{ self }:
let
  inherit (self.lists) singleton;
  inherit (self.strings) makeBinPath;
in
{
  # Wrap a package so every binary in it can find `packages` on PATH. Use this
  # for tools that shell out to helpers at runtime, where PATH is assembled by
  # something outside this configuration, such as activation running a package
  # manager that needs an interpreter and a shell.
  mkExtraPath =
    pkgs: package: packages:
    pkgs.symlinkJoin {
      inherit (package) name;
      inherit (package) meta;

      paths = singleton package;
      nativeBuildInputs = singleton pkgs.makeWrapper;

      postBuild = /* bash */ ''
        for binary in $out/bin/*; do
          wrapProgram "$binary" --suffix PATH : ${makeBinPath packages}
        done
      '';
    };
}
