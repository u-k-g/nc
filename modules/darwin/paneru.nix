{
  config,
  inputs,
  pkgs,
  ...
}:

let
  user = config.nc.user;
in
{
  home-manager.users.${user.name} = {
    imports = [ inputs.paneru.homeModules.paneru ];

    services.paneru = {
      enable = true;
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.paneru;

      settings = {
        options = {
          focus_follows_mouse = false;
          mouse_follows_focus = true;
          animation_speed = 37.0;
          auto_center = true;
          sliver_width = 1;
          window_hidden_ratio = 0.0;
        };

        decorations.workspace_menu_status = false;

        padding = {
          top = 4;
          bottom = 4;
          left = 8;
          right = 8;
        };

        swipe = {
          sensitivity = 0.88;
          snap_to_window = true;
          gesture = {
            fingers_count = 3;
            direction = "Reversed";
            vertical = true;
          };
          scroll.modifier = "ctrl + shift + cmd";
        };

        windows.default = {
          title = ".*";
          horizontal_padding = 4;
          vertical_padding = 4;
        };

        bindings = {
          window_virtualnum_1 = "alt - 1";
          window_virtualnum_2 = "alt - 2";
          window_virtualnum_3 = "alt - 3";
          window_virtualnum_4 = "alt - 4";
          window_virtualnum_5 = "alt - 5";
          window_virtualnum_6 = "alt - 6";
          window_virtualnum_7 = "alt - 7";
          window_virtualnum_8 = "alt - 8";
          window_virtualnum_9 = "alt - 9";

          window_virtualmovenum_1 = "alt + shift - 1";
          window_virtualmovenum_2 = "alt + shift - 2";
          window_virtualmovenum_3 = "alt + shift - 3";
          window_virtualmovenum_4 = "alt + shift - 4";
          window_virtualmovenum_5 = "alt + shift - 5";
          window_virtualmovenum_6 = "alt + shift - 6";
          window_virtualmovenum_7 = "alt + shift - 7";
          window_virtualmovenum_8 = "alt + shift - 8";
          window_virtualmovenum_9 = "alt + shift - 9";

          window_focus_west = "alt - h";
          window_focus_south = "alt + cmd - j";
          window_focus_north = "alt + cmd - k";
          window_focus_east = "alt - l";

          window_swap_west = "alt + shift - h";
          window_swap_east = "alt + shift - l";

          window_virtual_south = "alt - j";
          window_virtual_north = "alt - k";
          window_virtualmove_south = "alt + shift - j";
          window_virtualmove_north = "alt + shift - k";

          window_stack = "alt + shift - t";
          window_unstack = "alt + shift - g";
          window_manage = "alt + ctrl - f";
          window_fullwidth = "alt - f";
          window_snap = "alt - s";
          window_shrink = "alt + shift - minus";
          window_grow = "alt + shift - equal";
        };
      };
    };
  };
}
