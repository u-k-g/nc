{
  config,
  inputs,
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

      settings = {
        options = {
          focus_follows_mouse = false;
          mouse_follows_focus = true;
          animation_speed = 22.0;
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
          gesture.direction = "Reversed";
        };

        windows.default = {
          title = ".*";
          horizontal_padding = 4;
          vertical_padding = 4;
        };

        apps = {
          helium.name = "Helium";
          obsidian.name = "Obsidian";
          ghostty.name = "Ghostty";
          finder.name = "Finder";
          freecad.name = "FreeCAD";
          codex.name = "Codex";
          zed.name = "Zed";
          t3.name = "T3 Code (Nightly)";
        };

        bindings = {
          app_helium = "alt - w";
          app_obsidian = "alt - o";
          app_ghostty = "alt - g";
          app_finder = "alt - y";
          app_freecad = "alt - c";
          app_codex = "alt - r";
          app_zed = "alt - z";
          app_t3 = "alt - t";

          window_focus_west = "alt - h";
          window_focus_south = "alt - j";
          window_focus_north = "alt - k";
          window_focus_east = "alt - l";

          window_swap_west = "alt + shift - h";
          window_swap_south = "alt + shift - j";
          window_swap_north = "alt + shift - k";
          window_swap_east = "alt + shift - l";

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
