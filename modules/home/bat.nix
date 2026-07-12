{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatMapStringsSep;
  user = config.nc.user;

  lessOptions = [
    "--quit-if-one-screen"
    "--quit-on-intr"

    "--ignore-case"
    "--incsearch"
    "--LONG-PROMPT"
    "--no-edit-warn"

    "--chop-long-lines"
    "--HILITE-UNREAD"
    "--tilde"

    "--RAW-CONTROL-CHARS"
  ];

  manPager = pkgs.writeScriptBin "man-pager" /* nu */ ''
    #!${getExe pkgs.nushell}

    ^${getExe pkgs.unixtools.col} -bx
    | ^${getExe pkgs.bat} --language man --plain --color always
    | ^$env.PAGER
  '';

  cat = pkgs.writeScriptBin "cat" /* nu */ ''
    #!${getExe pkgs.nushell}

    def --wrapped main [...arguments: string] {
      let split = $arguments | group-by {|arg| if ($arg | path exists) { "files" } else { "options" } }

      match ($split.files? | default [] | length) {
        1 if (is-terminal --stdout) => {
          $env.LESSOPEN = $"||${getExe pkgs.bat} ($split.options? | default [] | str join ' ') --color always -- %s"
          exec $env.PAGER ...$split.files
        }

        _ => {
          exec ${getExe pkgs.bat} ...$arguments
        }
      }
    }
  '';

  sessionVariables = {
    MANROFFOPT = "-c";
    MANPAGER = getExe manPager;
    PAGER = getExe pkgs.less;
    LESSHISTFILE = "${user.homeDirectory}/.local/state/less/history";
    SYSTEMD_PAGERSECURE = "0";
  };
in
{
  environment.variables = sessionVariables;

  home-manager.users.${user.name} = { lib, ... }: {
    home.packages = [
      pkgs.bat
      pkgs.less
    ];

    home.sessionVariables = sessionVariables;

    home.activation.bat-cache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${user.homeDirectory}/.local/state/less
      run ${getExe pkgs.bat} cache --build
    '';

    programs.nushell.shellAliases = {
      less = "^$env.PAGER";
      cat = getExe cat;
    };

    xdg.configFile = {
      "lesskey".text = ''
        #env
        LESS = ${concatMapStringsSep " " (option: option) lessOptions}
      '';
      "bat/config".text = ''
        --theme 'base16'
      '';
      "bat/themes/base16.tmTheme".text = config.nc.theme.tmTheme;
    };
  };
}
