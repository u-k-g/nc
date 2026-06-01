{ lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.maccy ];

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

    CustomSystemPreferences."org.p0deje.Maccy" = {
      KeyboardShortcuts_delete = 0;
      KeyboardShortcuts_pin = 0;

      KeyboardShortcuts_popup = lib.strings.toJSON {
        carbonKeyCode = 9;
        carbonModifiers = 4352;
      };

      SUEnableAutomaticChecks = 0;

      enabledPasteboardTypes = [
        "public.png"
        "public.file-url"
        "public.utf8-plain-text"
        "public.rtf"
        "public.tiff"
        "public.html"
      ];

      menuIcon = "clipboard";
      popupPosition = "window";
      searchMode = "fuzzy";

      showFooter = 0;
      showSearch = 1;
      showTitle = 0;
    };
  };
}
