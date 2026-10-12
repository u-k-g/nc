# Git Whitelist Rules

- Keep `.gitignore` deny-by-default: start with `*`, then use only `!` rules to
  admit source file types within source directories and exact paths for docs,
  scripts, configuration, assets, and agent files. New source files in approved
  directories may be tracked automatically; other new files stay ignored until
  their paths are explicitly added.
- Never add targeted ignore rules. Keep the whitelist tight and simple, and
  admit only what the repository needs to track.
