{ ... }:

{
  networking = {
    computerName = "darwinbook";
    hostName = "darwinbook";
    localHostName = "darwinbook";
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleShowAllExtensions = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };

    LaunchServices.LSQuarantine = false;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

    CustomSystemPreferences."com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
      allowIdentifierForAdvertising = false;
      forceLimitAdTracking = true;
      personalizedAdsMigrated = false;
    };
  };
}
