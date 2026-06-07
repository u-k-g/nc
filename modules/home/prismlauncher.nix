{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    getExe
    hiPrio
    mkIf
    mkMerge
    ;
  user = config.nc.user;
  json = pkgs.formats.json { };
  ninjabrainBotJar = pkgs.fetchurl {
    url = "https://github.com/Ninjabrain1/Ninjabrain-Bot/releases/download/1.5.2/Ninjabrain-Bot-1.5.2.jar";
    hash = "sha256:1zsh2k3qv5ky88w2z733wmh8vbzp0mnyh01lq774l3d945iry2cq";
  };
  ninb = pkgs.writeShellApplication {
    name = "ninb";
    runtimeInputs = [ pkgs.jdk17 ];
    text = ''
      exec java -Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel -jar ${ninjabrainBotJar} "$@"
    '';
  };
  prismlauncherWithLibs = pkgs.prismlauncher.overrideAttrs (old: {
    qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
      "--prefix"
      "LD_LIBRARY_PATH"
      ":"
      (pkgs.lib.makeLibraryPath [
        pkgs.libX11
        pkgs.libXt
        pkgs.libXinerama
        pkgs.libxcb
        pkgs.libxkbcommon
        pkgs.libxtst
      ])
    ];
  });

  prismlauncherGamemode = hiPrio (
    pkgs.writeShellScriptBin "prismlauncher" ''
      exec ${pkgs.gamemode}/bin/gamemoderun ${prismlauncherWithLibs}/bin/prismlauncher "$@"
    ''
  );

  monitorWidth = 2560;
  monitorHeight = 1440;
  godSensMinecraft = 0.02291165;
  godSensWaywallNormal = 12.8000006;
  godSensWaywallTall = 1.1512141;
  thinBtWidth = builtins.floor ((monitorHeight * 1000.0) / 3571.0);
  thinBtHeight = monitorHeight;
  planarAbuseWidth = monitorWidth;
  planarAbuseHeight = builtins.floor (monitorWidth / 6.4);
  eyeMeasuringWidth = 384;
  eyeMeasuringHeight = 16384;
  eyeSeeSourceWidth = 60;
  eyeSeeSourceHeight = 580;
  eyeSeeProjectorWidth = builtins.floor ((monitorWidth - eyeMeasuringWidth) / 2.0);
  eyeSeeProjectorHeight = builtins.floor ((monitorHeight * eyeSeeProjectorWidth) / monitorWidth);
  eyeSeeOverlay = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/DuncanRuns/Jingle-EyeSee-Plugin/main/src/main/resources/overlay.png";
    hash = "sha256:1l1q0hkjwzip725zlyf5rfax671jrp3hhf6qsckn3m452dvqhzpb";
  };
  mcsrJvmArgs = lib.concatStringsSep " " [
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+UnlockDiagnosticVMOptions"
    "-XX:+UseG1GC"
    "-XX:MaxGCPauseMillis=50"
    "-XX:+AlwaysPreTouch"
    "-XX:+DisableExplicitGC"
    "-XX:+UseNUMA"
    "-XX:+UseTransparentHugePages"
    "-XX:+PerfDisableSharedMem"
    "-XX:+UseFastUnorderedTimeStamps"
    "-XX:+UseCriticalJavaThreadPriority"
    "-XX:ThreadPriorityPolicy=1"
    "-XX:ReservedCodeCacheSize=400M"
    "-XX:MaxInlineLevel=40"
  ];
  mcsrEnv = builtins.toJSON {
    __GL_THREADED_OPTIMIZATIONS = "0";
    LD_PRELOAD = "${pkgs.jemalloc}/lib/libjemalloc.so";
  };
  mcsrStandardSettings = builtins.fromJSON ''
    {
      ".apiVersion": "2.2+1.16-1.16.1",
      ".modVersion": "2.3+1.16-1.16.1",
      ".dataVersion": 0,
      "fov": 110.0,
      "realmsNotifications": { "enabled": false, "value": false },
      "fullscreenResolution": { "enabled": false, "value": null },
      "biomeBlendRadius": { "enabled": false, "value": 1.0 },
      "graphicsMode": { "enabled": false, "value": 0 },
      "renderDistance": 5.0,
      "ao": { "enabled": false, "value": 0 },
      "maxFps": 260.0,
      "enableVsync": { "enabled": false, "value": false },
      "bobView": false,
      "guiScale": 3,
      "attackIndicator": { "enabled": false, "value": 1 },
      "gamma": 5.0,
      "renderClouds": { "enabled": false, "value": 0 },
      "fullscreen": false,
      "particles": 2,
      "mipmapLevels": { "enabled": false, "value": 0.0 },
      "entityShadows": { "enabled": false, "value": false },
      "entityDistanceScaling": 0.5,
      "entityCulling": { "enabled": false, "value": false },
      "modelPart_cape": { "enabled": false, "value": false },
      "modelPart_jacket": { "enabled": false, "value": false },
      "modelPart_left_sleeve": { "enabled": false, "value": false },
      "modelPart_right_sleeve": { "enabled": false, "value": false },
      "modelPart_left_pants_leg": { "enabled": false, "value": false },
      "modelPart_right_pants_leg": { "enabled": false, "value": false },
      "modelPart_hat": { "enabled": false, "value": false },
      "mainHand": { "enabled": false, "value": 1 },
      "soundCategory_master": 1.0,
      "soundCategory_music": 0.0,
      "soundCategory_record": 0.0,
      "soundCategory_weather": 0.20,
      "soundCategory_block": 0.5,
      "soundCategory_hostile": 0.75,
      "soundCategory_neutral": 0.20,
      "soundCategory_player": 0.5,
      "soundCategory_ambient": 0.40,
      "soundCategory_voice": 0.50,
      "showSubtitles": true,
      "language": { "enabled": false, "value": "en_us" },
      "forceUnicodeFont": { "enabled": false, "value": false },
      "mouseSensitivity": ${toString godSensMinecraft},
      "invertYMouse": { "enabled": false, "value": false },
      "mouseWheelSensitivity": { "enabled": false, "value": 1.0 },
      "discrete_mouse_scroll": { "enabled": false, "value": false },
      "touchscreen": { "enabled": false, "value": false },
      "rawMouseInput": false,
      "autoJump": false,
      "key_key.jump": "key.keyboard.space",
      "key_key.sneak": "key.keyboard.left.shift",
      "key_key.sprint": "key.keyboard.g",
      "key_key.left": "key.keyboard.a",
      "key_key.right": "key.keyboard.d",
      "key_key.back": "key.keyboard.s",
      "key_key.forward": "key.keyboard.w",
      "key_key.attack": "key.mouse.left",
      "key_key.pickItem": "key.mouse.5",
      "key_key.use": "key.mouse.right",
      "key_key.drop": "key.keyboard.4",
      "key_key.hotbar.1": "key.keyboard.1",
      "key_key.hotbar.2": "key.keyboard.2",
      "key_key.hotbar.3": "key.keyboard.3",
      "key_key.hotbar.4": "key.keyboard.q",
      "key_key.hotbar.5": "key.keyboard.e",
      "key_key.hotbar.6": "key.keyboard.r",
      "key_key.hotbar.7": "key.keyboard.z",
      "key_key.hotbar.8": "key.keyboard.x",
      "key_key.hotbar.9": "key.keyboard.c",
      "key_key.inventory": "key.keyboard.f",
      "key_key.swapOffhand": "key.mouse.4",
      "key_key.loadToolbarActivator": "key.keyboard.left.bracket",
      "key_key.saveToolbarActivator": "key.keyboard.right.bracket",
      "key_key.playerlist": "key.keyboard.y",
      "key_key.chat": { "enabled": false, "value": "key.keyboard.t" },
      "key_key.command": { "enabled": false, "value": "key.keyboard.slash" },
      "key_key.advancements": { "enabled": false, "value": "key.keyboard.l" },
      "key_key.spectatorOutlines": { "enabled": false, "value": "key.keyboard.unknown" },
      "key_key.screenshot": { "enabled": false, "value": "key.keyboard.f2" },
      "key_key.smoothCamera": { "enabled": false, "value": "key.keyboard.unknown" },
      "key_key.fullscreen": { "enabled": false, "value": "key.keyboard.f11" },
      "key_key.togglePerspective": "key.keyboard.tab",
      "key_Create New World": { "enabled": false, "value": "key.keyboard.f6" },
      "key_speedrunigt.controls.start_timer": { "enabled": false, "value": "key.keyboard.u" },
      "key_speedrunigt.controls.stop_timer": { "enabled": false, "value": "key.keyboard.i" },
      "chatVisibility": { "enabled": false, "value": 0 },
      "chatColors": { "enabled": false, "value": true },
      "chatLinks": { "enabled": false, "value": true },
      "chatLinksPrompt": { "enabled": false, "value": true },
      "chatOpacity": { "enabled": false, "value": 1.0 },
      "textBackgroundOpacity": { "enabled": false, "value": 0.5 },
      "chatScale": { "enabled": false, "value": 1.0 },
      "chatLineSpacing": { "enabled": false, "value": 0.0 },
      "chatWidth": { "enabled": false, "value": 1.0 },
      "chatHeightFocused": { "enabled": false, "value": 1.0 },
      "chatHeightUnfocused": { "enabled": false, "value": 0.44366195797920227 },
      "narrator": { "enabled": false, "value": 0 },
      "autoSuggestions": { "enabled": false, "value": true },
      "reducedDebugInfo": { "enabled": false, "value": false },
      "backgroundForChatOnly": { "enabled": false, "value": 1 },
      "chatDelay": { "enabled": false, "value": 0.0 },
      "toggleCrouch": 0,
      "toggleSprint": 1,
      "pauseOnLostFocus": { "enabled": false, "value": false },
      "advancedItemTooltips": { "enabled": false, "value": false },
      "hitboxes": false,
      "chunkborders": false,
      "pieDirectory": "root.gameRenderer.level.entities",
      "perspective": { "enabled": false, "value": 0 },
      "f1": { "enabled": false, "value": false },
      "sneaking": { "enabled": false, "value": false },
      "sprinting": { "enabled": false, "value": false },
      "fovOnWorldJoin": 110.0,
      "renderDistanceOnWorldJoin": 5.0,
      "entityDistanceScalingOnWorldJoin": 0.5,
      "guiScaleOnWorldJoin": 3,
      "toggleStandardSettings": true,
      "toggleAll": false,
      "autoF3Esc": true,
      "firstAutoF3EscDelay": 22,
      "triggerOnResize": false
    }
  '';
  mcsrStandardSettingsFile = json.generate "mcsr-standardsettings.json" mcsrStandardSettings;
  mcsrInstanceCfgTarget = "${user.homeDirectory}/.local/share/PrismLauncher/instances/mcsr/instance.cfg";
  mcsrStandardSettingsTarget = "${user.homeDirectory}/.local/share/PrismLauncher/instances/mcsr/minecraft/config/mcsr/standardsettings.json";
  ninjabrainPrefsTarget = "${user.homeDirectory}/.java/.userPrefs/ninjabrainbot/prefs.xml";
  ninjabrainPrefs = pkgs.writeText "ninjabrain-prefs.xml" ''
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">
        <map MAP_XML_VERSION="1.0">
          <entry key="settings_version" value="3"/>
          <entry key="auto_reset" value="true"/>
          <entry key="view" value="1"/>
          <entry key="size" value="1"/>
          <entry key="color_negative_coords" value="true"/>
          <entry key="show_angle_updates" value="true"/>
          <entry key="show_angle_errors" value="true"/>
          <entry key="use_adv_statistics" value="true"/>
          <entry key="enable_http_server" value="true"/>
          <entry key="mismeasure_warning_enabled" value="true"/>
          <entry key="portal_linking_warning_enabled" value="true"/>
          <entry key="combined_offset_information_enabled" value="true"/>
          <entry key="direction_help_enabled" value="true"/>
          <entry key="angle_adjustment_display_type" value="1"/>
          <entry key="angle_adjustment_type" value="1"/>
          <entry key="resolution_height" value="16384.0"/>
          <entry key="hotkey_increment_modifier" value="0"/>
          <entry key="hotkey_increment_code" value="65588"/>
          <entry key="hotkey_decrement_modifier" value="0"/>
          <entry key="hotkey_decrement_code" value="65587"/>
          <entry key="use_precise_angle" value="true"/>
          <entry key="default_boat_type" value="2"/>
          <entry key="sigma_boat" value="0.0001"/>
          <entry key="sensitivity" value="${toString godSensMinecraft}"/>
        </map>
  '';
in
{
  home-manager.users.${user.name} = mkMerge [
    {
      home.packages = [
        (if pkgs.stdenv.isLinux then prismlauncherGamemode else pkgs.prismlauncher)
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        ninb
        pkgs.waywall
      ];
    }

    (mkIf pkgs.stdenv.isLinux {
      xdg.configFile."waywall/init.lua".text = ''
        local waywall = require("waywall")
        local helpers = require("waywall.helpers")

        local normal_width = 0
        local normal_height = 0
        local eye_mirror = nil
        local eye_overlay = nil
        local ninb_autoshow_text = nil
        local ninb_autoshow_serial = 0

        local function close_eye_see()
            if eye_mirror ~= nil then
                eye_mirror:close()
                eye_mirror = nil
            end

            if eye_overlay ~= nil then
                eye_overlay:close()
                eye_overlay = nil
            end
        end

        local function is_active_res(width, height)
            local current_width, current_height = waywall.active_res()
            return current_width == width and current_height == height
        end

        local function reset_res()
            close_eye_see()
            waywall.set_resolution(normal_width, normal_height)
            waywall.set_sensitivity(${toString godSensWaywallNormal})
        end

        local function toggle_res(width, height)
            close_eye_see()

            if is_active_res(width, height) then
                reset_res()
                return
            end

            waywall.set_resolution(width, height)
        end

        local function toggle_eye_measuring()
            if is_active_res(${toString eyeMeasuringWidth}, ${toString eyeMeasuringHeight}) then
                reset_res()
                return
            end

            waywall.set_resolution(${toString eyeMeasuringWidth}, ${toString eyeMeasuringHeight})
            waywall.set_sensitivity(${toString godSensWaywallTall})
            close_eye_see()

            local dst = {
                x = 0,
                y = ${toString (builtins.floor ((monitorHeight - eyeSeeProjectorHeight) / 2.0))},
                w = ${toString eyeSeeProjectorWidth},
                h = ${toString eyeSeeProjectorHeight},
            }

            eye_mirror = waywall.mirror({
                src = {
                    x = ${toString (builtins.floor ((eyeMeasuringWidth - eyeSeeSourceWidth) / 2.0))},
                    y = ${toString (builtins.floor ((eyeMeasuringHeight - eyeSeeSourceHeight) / 2.0))},
                    w = ${toString eyeSeeSourceWidth},
                    h = ${toString eyeSeeSourceHeight},
                },
                dst = dst,
                depth = 10,
            })

            eye_overlay = waywall.image("${eyeSeeOverlay}", {
                dst = dst,
                depth = 11,
            })
        end

        local function set_ninb_autoshow_text(text)
            if ninb_autoshow_text ~= nil then
                ninb_autoshow_text:close()
                ninb_autoshow_text = nil
            end

            if text == nil then
                return
            end

            ninb_autoshow_text = waywall.text(text, {
                x = ${toString (monitorWidth - 160)},
                y = ${toString (monitorHeight - 120)},
                color = "#fabd2fff",
                size = 2,
                depth = 20,
            })
        end

        local function launch_ninjabrain()
            waywall.exec("${getExe ninb}")
            waywall.show_floating(true)
        end

        local function toggle_ninjabrain()
            set_ninb_autoshow_text(nil)
            ninb_autoshow_serial = ninb_autoshow_serial + 1
            waywall.show_floating(not waywall.floating_shown())
        end

        local function autoshow_ninjabrain()
            if not waywall.get_key("f3") then
                return false
            end

            if waywall.floating_shown() and ninb_autoshow_text == nil then
                return false
            end

            ninb_autoshow_serial = ninb_autoshow_serial + 1
            local serial = ninb_autoshow_serial

            waywall.press_key("C")
            waywall.show_floating(true)

            for i = 8, 1, -1 do
                if serial ~= ninb_autoshow_serial then
                    return
                end

                set_ninb_autoshow_text(tostring(i) .. "s")
                waywall.sleep(1000)
            end

            waywall.show_floating(false)
            set_ninb_autoshow_text(nil)
        end

        local config = {
            input = {
                layout = "us",
                repeat_rate = 40,
                repeat_delay = 300,
                sensitivity = ${toString godSensWaywallNormal},
                confine_pointer = true,
            },

            theme = {
                background = "#1d2021ff",
                ninb_anchor = "right",
                ninb_opacity = 0.8,
            },

            experimental = {
                tearing = true,
            },

            shaders = {
                f3 = {
                    fragment = [[
                        precision highp float;

                        varying vec2 f_src_pos;

                        uniform sampler2D u_texture;

                        const vec3 threshold = vec3(0.01);

                        const vec3 unpaused = vec3(0.867);
                        const vec3 paused = vec3(0.263);

                        void main() {
                            vec4 color = texture2D(u_texture, f_src_pos);

                            if (all(lessThan(abs(color.rgb - unpaused), threshold)) || all(lessThan(abs(color.rgb - paused), threshold))) {
                                gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
                            } else {
                                gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
                            }
                        }
                    ]],
                },

                pie_chart = {
                    fragment = [[
                        precision highp float;

                        varying vec2 f_src_pos;

                        uniform sampler2D u_texture;

                        const vec3 threshold = vec3(0.01);
                        const vec3 pink = vec3(0.882, 0.271, 0.761);
                        const vec3 pink2 = vec3(0.894, 0.275, 0.769);
                        const vec3 orange = vec3(0.914, 0.427, 0.302);
                        const vec3 orange2 = vec3(0.925, 0.431, 0.306);
                        const vec3 green = vec3(0.271, 0.796, 0.396);
                        const vec3 green2 = vec3(0.271, 0.800, 0.396);

                        void main() {
                            vec4 color = texture2D(u_texture, f_src_pos);

                            bool is_pink = all(lessThan(abs(color.rgb - pink), threshold))
                                || all(lessThan(abs(color.rgb - pink2), threshold));
                            bool is_orange = all(lessThan(abs(color.rgb - orange), threshold))
                                || all(lessThan(abs(color.rgb - orange2), threshold));
                            bool is_green = all(lessThan(abs(color.rgb - green), threshold))
                                || all(lessThan(abs(color.rgb - green2), threshold));

                            if (is_pink || is_orange || is_green) {
                                gl_FragColor = color;
                            } else {
                                gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
                            }
                        }
                    ]],
                },
            },
        }

        local function add_debug_mirrors(width, height, lower_y)
            helpers.res_mirror({
                src = { x = 0, y = 28, w = 49, h = 9 },
                dst = { x = 1120, y = 400, w = 196, h = 36 },
                shader = "f3",
                depth = 1,
            }, width, height)

            helpers.res_mirror({
                src = { x = 0, y = 36, w = 49, h = 9 },
                dst = { x = 1120, y = 440, w = 196, h = 36 },
                shader = "f3",
                depth = 1,
            }, width, height)

            helpers.res_mirror({
                src = { x = 14, y = 38, w = 5, h = 7 },
                dst = { x = 930, y = 782, w = 40, h = 56 },
                shader = "f3",
                depth = 1,
            }, width, height)

            helpers.res_mirror({
                src = { x = 0, y = lower_y, w = width, h = 260 },
                dst = { x = 800, y = 586, w = 384, h = 260 },
                shader = "pie_chart",
            }, width, height)

            helpers.res_mirror({
                src = { x = math.floor(width * 0.71), y = lower_y + 184, w = 40, h = 24 },
                dst = { x = 1120, y = 600, w = 196, h = 144 },
            }, width, height)
        end

        add_debug_mirrors(${toString thinBtWidth}, ${toString thinBtHeight}, ${toString (thinBtHeight - 404)})
        add_debug_mirrors(${toString eyeMeasuringWidth}, ${toString eyeMeasuringHeight}, ${
          toString (eyeMeasuringHeight - 404)
        })

        helpers.res_mirror({
            src = { x = ${toString (builtins.floor ((eyeMeasuringWidth - 220) / 2.0))}, y = ${
              toString (eyeMeasuringHeight - 40)
            }, w = 220, h = 40 },
            dst = { x = 630, y = 960, w = 660, h = 120 },
        }, ${toString eyeMeasuringWidth}, ${toString eyeMeasuringHeight})

        helpers.res_mirror({
            src = { x = ${toString (eyeMeasuringWidth - 189)}, y = ${
              toString (eyeMeasuringHeight - 105)
            }, w = 124, h = 80 },
            dst = { x = 1545, y = 765, w = 372, h = 240 },
        }, ${toString eyeMeasuringWidth}, ${toString eyeMeasuringHeight})

        helpers.res_mirror({
            src = { x = ${toString (thinBtWidth - 189)}, y = ${toString (thinBtHeight - 105)}, w = 124, h = 80 },
            dst = { x = 1545, y = 765, w = 372, h = 240 },
        }, ${toString thinBtWidth}, ${toString thinBtHeight})

        config.actions = {
            ["V"] = function()
                toggle_res(${toString thinBtWidth}, ${toString thinBtHeight})
            end,

            ["B"] = function()
                toggle_res(${toString planarAbuseWidth}, ${toString planarAbuseHeight})
            end,

            ["J"] = function()
                toggle_eye_measuring()
            end,

            ["Ctrl-Shift-N"] = function()
                launch_ninjabrain()
            end,

            ["backslash"] = function()
                toggle_ninjabrain()
            end,

            ["*-C"] = function()
                return autoshow_ninjabrain()
            end,
        }

        waywall.listen("state", function(state)
            if state.screen ~= "inworld" then
                reset_res()
            end
        end)

        return config
      '';

      xdg.dataFile."applications/org.prismlauncher.PrismLauncher.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=PrismLauncher
          GenericName=Minecraft Launcher
          Comment=Launch PrismLauncher through GameMode
          Exec=${prismlauncherGamemode}/bin/prismlauncher %u
          Terminal=false
          Categories=Game;
          StartupNotify=true
        '';
      };

      home.activation.mcsr-standardsettings =
        config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
          ''
            target=${lib.escapeShellArg mcsrStandardSettingsTarget}
            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
            ${pkgs.coreutils}/bin/rm -f "$target"
            ${pkgs.coreutils}/bin/install -m 0666 ${mcsrStandardSettingsFile} "$target"
          '';

      home.activation.ninjabrain-prefs =
        config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
          ''
            target=${lib.escapeShellArg ninjabrainPrefsTarget}
            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
            ${pkgs.coreutils}/bin/rm -f "$target"
            ${pkgs.coreutils}/bin/install -m 0644 ${ninjabrainPrefs} "$target"
          '';

      home.activation.mcsr-waywall =
        config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
          ''
            target=${lib.escapeShellArg mcsrInstanceCfgTarget}
            if [ -e "$target" ]; then
              MCSR_ENV=${lib.escapeShellArg mcsrEnv} ${pkgs.perl}/bin/perl -0pi -e '
                s@^OverrideCommands=.*@OverrideCommands=true@m or $_ .= "\nOverrideCommands=true\n";
                s@^WrapperCommand=.*@WrapperCommand=${pkgs.coreutils}/bin/env __GL_THREADED_OPTIMIZATIONS=0 ${pkgs.waywall}/bin/waywall wrap --@m or $_ .= "WrapperCommand=${pkgs.coreutils}/bin/env __GL_THREADED_OPTIMIZATIONS=0 ${pkgs.waywall}/bin/waywall wrap --\n";
                s@^JavaPath=.*@JavaPath=${pkgs.jdk8}/bin/java@m or $_ .= "JavaPath=${pkgs.jdk8}/bin/java\n";
                s@^JvmArgs=.*@JvmArgs=${mcsrJvmArgs}@m or $_ .= "JvmArgs=${mcsrJvmArgs}\n";
                s@^MaxMemAlloc=.*@MaxMemAlloc=4096@m or $_ .= "MaxMemAlloc=4096\n";
                s@^MinMemAlloc=.*@MinMemAlloc=4096@m or $_ .= "MinMemAlloc=4096\n";
                s@^OverrideEnv=.*@OverrideEnv=true@m or $_ .= "OverrideEnv=true\n";
                s@^Env=.*@"Env=".$ENV{MCSR_ENV}@me or $_ .= "Env=".$ENV{MCSR_ENV}."\n";
                s@^OverrideJavaArgs=.*@OverrideJavaArgs=true@m or $_ .= "OverrideJavaArgs=true\n";
                s@^OverrideJavaLocation=.*@OverrideJavaLocation=true@m or $_ .= "OverrideJavaLocation=true\n";
                s@^OverrideMemory=.*@OverrideMemory=true@m or $_ .= "OverrideMemory=true\n";
                s@^OverrideNativeWorkarounds=.*@OverrideNativeWorkarounds=true@m or $_ .= "OverrideNativeWorkarounds=true\n";
                s@^UseNativeGLFW=.*@UseNativeGLFW=true@m or $_ .= "UseNativeGLFW=true\n";
                s@^CustomGLFWPath=.*@CustomGLFWPath=@m or $_ .= "CustomGLFWPath=\n";
              ' "$target"
            fi
          '';
    })
  ];
}
