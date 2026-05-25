{ pkgs, ... }:

{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    gamemode.enable = true;
    gamescope.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
  ];
}
