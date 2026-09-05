# Hermes

After activating Manara’s NixOS configuration, apply `hosts/policy.hujson`
to the tailnet’s access policy.

Open <https://manara.tail4b71d2.ts.net:8443>. On first visit, choose
**Gateway settings**, sign in as `ukg`, then reload the page.
Manara is already selected.
Get the generated password on Manara:

```sh
sed -n 's/^HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=//p' ~/.hermes/dashboard.env
```

Set the provider, API key and model in Hermes. State persists in `~/.hermes`.
