{
  pnpm,
  writeShellApplication,
}:

writeShellApplication {
  name = "pi";

  runtimeInputs = [ pnpm ];

  text = ''
    exec pnpm --config.ignore-scripts=true dlx @earendil-works/pi-coding-agent@0.78.0 "$@"
  '';
}
