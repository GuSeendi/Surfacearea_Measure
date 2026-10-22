# Limitations

- Static package evidence establishes shipped metadata and contents, not runtime behavior.
- Hopper timed out during initial analysis of the 237 MB executable. The tool-owned provider processes were terminated and its temporary runtime directory was moved to Trash, but the active MCP connection retains stale cleanup state until restarted. No native string/procedure result is treated as evidence.
- Code-signing inspection was bound to a digest-verified Mach-O snapshot and did not independently perform full trust-chain validation of the mounted app bundle.
- No application launch, user-data access, account sign-in or network capture was performed.
- No proprietary code, assets, credentials or license material are stored in this repository.
