{ ... }:

{
  system.defaults = {
    loginwindow = {
      DisableConsoleAccess = true;
      GuestEnabled = false;
    };

    CustomSystemPreferences."com.apple.screensaver" = {
      askForPassword = 1;
      askForPasswordDelay = 0;
    };
  };
}
