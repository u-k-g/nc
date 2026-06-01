{ ... }:

{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "overload(hyper, esc)";

          # Keep the Cmd/Win-position key as the WM modifier and make Alt behave like Ctrl.
          leftmeta = "leftalt";
          leftalt = "leftcontrol";
          rightmeta = "rightalt";
          rightalt = "rightcontrol";
        };

        "hyper:C-M-A-S" = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
      };
    };
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';
}
