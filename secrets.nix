let
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    elem
    filter
    foldl'
    listToAttrs
    match
    pathExists
    readDir
    readFileType
    ;

  keys = import ./keys.nix;

  singleton = value: [ value ];
  optional = condition: consequence: if condition then [ consequence ] else [ ];
  uniq = foldl' (acc: item: if elem item acc then acc else acc ++ singleton item) [ ];

  listFilesRecursive =
    base: directory:
    if !pathExists directory then
      [ ]
    else if readFileType directory != "directory" then
      singleton base
    else
      let
        entries = readDir directory;
        names = attrNames entries;
      in
      concatMap (
        name:
        if entries.${name} == "directory" then
          listFilesRecursive "${base}/${name}" /${directory}/${name}
        else if entries.${name} == "regular" then
          singleton "${base}/${name}"
        else
          [ ]
      ) names;

  isAge = name: match ".*\\.age$" name != null;

  hostSecrets = concatMap (
    host:
    map (path: {
      name = path;
      value.publicKeys = uniq (optional (keys.hosts ? ${host}) keys.hosts.${host} ++ keys.admins);
    }) (filter isAge (listFilesRecursive "hosts/${host}" ./hosts/${host}))
  ) (attrNames (readDir ./hosts));

  moduleSecrets = map (path: {
    name = path;
    value.publicKeys = uniq (attrValues keys.users ++ keys.admins);
  }) (filter isAge (listFilesRecursive "modules" ./modules));

  repoSecrets = map (path: {
    name = path;
    value.publicKeys = keys.admins;
  }) (filter isAge (listFilesRecursive "secrets" ./secrets));
in
listToAttrs (hostSecrets ++ moduleSecrets ++ repoSecrets)
