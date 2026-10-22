# Findings

## Local read-only observations

- The official DMG downloaded from SketchUp has SHA-256 `3a89d6ea7a5eddbd97521bde884f528f2dd6348b6408b74651551fb89d27c344` and size 1,493,353,715 bytes.
- A read-only mount contains `SketchUp.app` and `LayOut.app` under `SketchUp 2026`.
- The SketchUp bundle reports version 26.2, build 26.2.242 and bundle identifier `com.sketchup.SketchUp.2026`.
- The 35,099,328-byte main executable is a Universal Mach-O with x86_64 and arm64 slices. SHA-256: `b0a17de5830826e217dee276305d4af4208dbe2965a730dea23af4f66f40c3ad`.
- macOS code-signing metadata identifies Trimble Inc. team `J8PVMCY7KL` and hardened runtime.

These facts were collected with read-only macOS utilities, not REA Evidence. REA refused the target because cleanup of the previous large Hopper analysis remained unconfirmed in the active MCP connection.

## Clean-room relevance

- SketchUp remains a useful runtime reference for inference cues, target stability and immediate face-closure feedback.
- No implementation detail is inferred from the package identity. Any reusable behavior must be observed in a bounded blank-document scenario or established by official public documentation.

## Unknowns

- Snap priority, inference thresholds, hysteresis and face-generation logic were not observed.
- No runtime scenario, account sign-in, existing document access or network capture was performed.
- No native string, procedure or pseudocode result is claimed.

