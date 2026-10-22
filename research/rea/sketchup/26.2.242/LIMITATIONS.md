# Limitations

- REA did not accept this target in the current connection because the earlier Hopper session left stale cleanup state. Its provider processes and temporary runtime files were cleaned up, but a fresh MCP connection is required.
- Local read-only plist, architecture, digest and code-signing checks are not REA Evidence and do not establish runtime behavior.
- DMG mounting used `-noverify` only after the complete downloaded file was independently bound to its recorded SHA-256 digest.
- No application launch, user-data access, account sign-in or network capture was performed.
- No proprietary code, assets, credentials or license material are stored in this repository.
