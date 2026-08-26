{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.writeShellApplication {
        name = "nc-fmt";
        runtimeInputs = [
          pkgs.nixfmt
          pkgs.ripgrep
        ];
        text = /* bash */ ''
          if [ "$#" -eq 0 ]; then
            rg --files -g '*.nix' | xargs nixfmt
          else
            nixfmt "$@"
          fi
        '';
      };
    };
}
