{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) hiPrio mkIf mkMerge;
  user = config.nc.user;
  json = pkgs.formats.json { };

  prismlauncherGamemode = hiPrio (
    pkgs.writeShellScriptBin "prismlauncher" ''
      exec ${pkgs.gamemode}/bin/gamemoderun ${pkgs.prismlauncher}/bin/prismlauncher "$@"
    ''
  );

  mcsrStandardSettings = {
    ".apiVersion" = "2.2+1.16-1.16.1";
    ".modVersion" = "2.3+1.16-1.16.1";
    ".dataVersion" = 0;
    _comment_sprint = "R -> remap mouse thumb button (mouse4) to R in your mouse software";
    _comment_drop = "Q -> optional: remap mouse5 to Q if you keep hitting it by accident while strafing";
    _comment_pickitem = "mouse.middle is fine, but you can remap mouse5 to G if you want";
    fov = 90.0;
    realmsNotifications = false;
    fullscreenResolution = null;
    biomeBlendRadius = 1.0;
    graphicsMode = 0;
    renderDistance = 12.0;
    ao = 0;
    maxFps = 260.0;
    enableVsync = false;
    bobView = false;
    guiScale = 2;
    attackIndicator = 1;
    gamma = 100.0;
    renderClouds = 0;
    fullscreen = false;
    particles = 2;
    mipmapLevels = 0.0;
    entityShadows = false;
    entityDistanceScaling = 1.0;
    entityCulling = true;
    modelPart_cape = false;
    modelPart_jacket = false;
    modelPart_left_sleeve = false;
    modelPart_right_sleeve = false;
    modelPart_left_pants_leg = false;
    modelPart_right_pants_leg = false;
    modelPart_hat = false;
    mainHand = 1;
    soundCategory_master = 1.0;
    soundCategory_music = 0.0;
    soundCategory_record = 0.0;
    soundCategory_weather = 0.5;
    soundCategory_block = 1.0;
    soundCategory_hostile = 1.0;
    soundCategory_neutral = 1.0;
    soundCategory_player = 1.0;
    soundCategory_ambient = 0.5;
    soundCategory_voice = 1.0;
    showSubtitles = false;
    language = "en_us";
    forceUnicodeFont = false;
    mouseSensitivity = 0.5;
    invertYMouse = false;
    mouseWheelSensitivity = 1.0;
    discrete_mouse_scroll = false;
    touchscreen = false;
    rawMouseInput = true;
    autoJump = false;
    "key_key.jump" = "key.keyboard.space";
    "key_key.sneak" = "key.keyboard.left.shift";
    "key_key.sprint" = "key.keyboard.r";
    "key_key.left" = "key.keyboard.a";
    "key_key.right" = "key.keyboard.d";
    "key_key.back" = "key.keyboard.s";
    "key_key.forward" = "key.keyboard.w";
    "key_key.attack" = "key.mouse.left";
    "key_key.pickItem" = "key.mouse.middle";
    "key_key.use" = "key.mouse.right";
    "key_key.drop" = "key.keyboard.q";
    "key_key.hotbar.1" = "key.keyboard.1";
    "key_key.hotbar.2" = "key.keyboard.2";
    "key_key.hotbar.3" = "key.keyboard.3";
    "key_key.hotbar.4" = "key.keyboard.4";
    "key_key.hotbar.5" = "key.keyboard.5";
    "key_key.hotbar.6" = "key.keyboard.6";
    "key_key.hotbar.7" = "key.keyboard.7";
    "key_key.hotbar.8" = "key.keyboard.8";
    "key_key.hotbar.9" = "key.keyboard.9";
    "key_key.inventory" = "key.keyboard.e";
    "key_key.swapOffhand" = "key.keyboard.f";
    "key_key.loadToolbarActivator" = "key.keyboard.unknown";
    "key_key.saveToolbarActivator" = "key.keyboard.unknown";
    "key_key.playerlist" = "key.keyboard.tab";
    "key_key.chat" = "key.keyboard.t";
    "key_key.command" = "key.keyboard.slash";
    "key_key.advancements" = "key.keyboard.l";
    "key_key.spectatorOutlines" = "key.keyboard.unknown";
    "key_key.screenshot" = "key.keyboard.f2";
    "key_key.smoothCamera" = "key.keyboard.unknown";
    "key_key.fullscreen" = "key.keyboard.f11";
    "key_key.togglePerspective" = "key.keyboard.f5";
    "key_speedrunigt.controls.start_timer" = "key.keyboard.u";
    "key_speedrunigt.controls.stop_timer" = "key.keyboard.i";
    chatVisibility = 0;
    chatColors = true;
    chatLinks = true;
    chatLinksPrompt = true;
    chatOpacity = 1.0;
    textBackgroundOpacity = 0.5;
    chatScale = 1.0;
    chatLineSpacing = 0.0;
    chatWidth = 1.0;
    chatHeightFocused = 1.0;
    chatHeightUnfocused = 0.44366195797920227;
    narrator = 0;
    autoSuggestions = true;
    reducedDebugInfo = false;
    backgroundForChatOnly = 1;
    chatDelay = 0.0;
    toggleCrouch = 0;
    toggleSprint = 0;
    pauseOnLostFocus = false;
    advancedItemTooltips = false;
    hitboxes = {
      enabled = false;
      value = false;
    };
    chunkborders = {
      enabled = false;
      value = false;
    };
    pieDirectory = {
      enabled = false;
      value = "root";
    };
    perspective = {
      enabled = false;
      value = 0;
    };
    f1 = {
      enabled = false;
      value = false;
    };
    sneaking = {
      enabled = false;
      value = false;
    };
    sprinting = {
      enabled = false;
      value = false;
    };
    fovOnWorldJoin = {
      enabled = true;
      value = 90.0;
    };
    renderDistanceOnWorldJoin = {
      enabled = true;
      value = 12.0;
    };
    entityDistanceScalingOnWorldJoin = {
      enabled = true;
      value = 1.0;
    };
    guiScaleOnWorldJoin = {
      enabled = true;
      value = 2;
    };
    toggleStandardSettings = true;
    toggleAll = true;
    autoF3Esc = true;
    firstAutoF3EscDelay = 22;
    triggerOnResize = true;
  };
in
{
  home-manager.users.${user.name} = mkMerge [
    {
      home.packages = [
        (if pkgs.stdenv.isLinux then prismlauncherGamemode else pkgs.prismlauncher)
      ];
    }

    (mkIf pkgs.stdenv.isLinux {
      xdg.desktopEntries.prismlauncher-gamemode = {
        name = "PrismLauncher (GameMode)";
        genericName = "Minecraft Launcher";
        comment = "Launch PrismLauncher through GameMode";
        exec = "${prismlauncherGamemode}/bin/prismlauncher %u";
        terminal = false;
        categories = [ "Game" ];
      };

      xdg.dataFile."PrismLauncher/instances/mcsr/minecraft/config/mcsr/standardsettings.json" = {
        source = json.generate "mcsr-standardsettings.json" mcsrStandardSettings;
        force = true;
      };
    })
  ];
}
