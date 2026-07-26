{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.amp = pkgs.callPackage (
        {
          lib,
          nushell,
          writeTextFile,
        }:
        let
          inherit (lib.meta) getExe;
          inherit (lib.strings) fileContents;
        in
        writeTextFile {
          name = "amp";
          destination = "/bin/amp";
          executable = true;
          text = ''
            #!${getExe nushell}
            ${fileContents ./amp/amp.nu}
          '';
        }
      ) { };
    };
}
