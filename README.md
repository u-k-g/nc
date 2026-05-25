# NC

**nix collective**

this repo borrows heavily from RGBCube's ncc:
https://github.com/RGBCube/ncc

## secrets

create or edit a secret:

```sh
RULES=./secrets.nix agenix -e secrets/name.age -i ~/.config/agenix/keys.txt
```

rekey all secrets after changing `keys.nix`:

```sh
RULES=./secrets.nix agenix -r -i ~/.config/agenix/keys.txt
```

decrypt a secret:

```sh
agenix -d secrets/name.age -i ~/.config/agenix/keys.txt
```

use a secret in nix:

```nix
config.age.secrets.name.path
```
