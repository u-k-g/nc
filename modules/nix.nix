{ ... }:

{
  nix = {
    enable = true;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];

      extra-substituters = [
        "https://cache.garnix.io/"
      ];

      extra-trusted-public-keys = [
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];

      builders-use-substitutes = true;
      flake-registry = "";
      http-connections = 50;
      show-trace = true;
      trusted-users = [
        "root"
        "@admin"
        "@wheel"
      ];
      use-xdg-base-directories = true;
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    optimise.automatic = true;
  };
}
