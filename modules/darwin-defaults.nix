{ config, ... }:

{
  networking = {
    computerName = "macbook";
    hostName = "macbook";
    localHostName = "macbook";
  };

  system.defaults = {
    dock = {
      autohide = true;
      showhidden = true;
      mouse-over-hilite-stack = true;
      show-recents = false;
      mru-spaces = false;
      tilesize = 48;
      magnification = false;
      enable-spring-load-actions-on-all-items = true;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    loginwindow = {
      DisableConsoleAccess = true;
      GuestEnabled = false;
    };

    screencapture = {
      location = "${config.nc.user.homeDirectory}/Downloads";
      type = "png";
    };

    trackpad = {
      Clicking = false;
      Dragging = false;
    };

    menuExtraClock = {
      Show24Hour = true;
      ShowSeconds = true;
    };

    controlcenter = {
      BatteryShowPercentage = true;
      Bluetooth = true;
    };

    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleShowAllExtensions = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };

    LaunchServices.LSQuarantine = false;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

    CustomSystemPreferences = {
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
        forceLimitAdTracking = true;
        personalizedAdsMigrated = false;
      };

      "com.apple.dock" = {
        autohide-time-modifier = 0.0;
        autohide-delay = 0.0;
        expose-animation-duration = 0.0;
        springboard-show-duration = 0.0;
        springboard-hide-duration = 0.0;
        springboard-page-duration = 0.0;
        wvous-tl-corner = 0;
        wvous-tr-corner = 0;
        wvous-bl-corner = 0;
        wvous-br-corner = 0;
        launchanim = 0;
      };

      "com.apple.screensaver" = {
        askForPassword = 1;
        askForPasswordDelay = 0;
      };
    };
  };
}
