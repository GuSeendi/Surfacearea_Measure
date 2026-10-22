# Findings

## Observations

- REA inventoried the official Shapr3D DMG as a shipped archive. Artifact SHA-256: `41045229ef8a00e939e3b7ab9032c398a16723b667cb7a25ce61a191e9bdc8f0`.
- The complete package inventory contains 5,412 content-addressed nodes, 5,744 path occurrences and 5,730 edges, with no reported integrity contradictions. Evidence: `ev_86fe7b81d359e47f2fad10618f936361bc5beb9d190c628486f3544d11f2f0f6`, parent `ev_2931484256c701dfa4f437cb51a1817713cb052c459e1eecfe30291d32258961`, inventory `ev_a8141d81ec3a3eace8c6a6a5e1ef454336c83dfbb3c383c25e51b8103e542128`.
- The main executable is a 237,113,440-byte unencrypted Universal Mach-O with x86_64 and arm64 slices. Main executable SHA-256: `fc5bf63604064b764c3c4694375239841b6e87d899f3e0f323edf891d6511174`. Evidence: `ev_8198b03717cfe5e2b127f886dcef069e40ab1e3d09f828c91c5de8760e6eae23` and `ev_bec8c549f8294789c3f03e85347e0f112ead053628f8a33ef81e8c26a5d9734d`.
- Bundle metadata identifies Shapr3D 26.180.0, build 11926, bundle identifier `com.shapr3d.shapr`, minimum macOS 14.0. Evidence: `ev_c17d02f72f8d56e3547e6000917d826c2bd7b2f2f03ee880dcc5877cffa9f51e`.
- The executable is signed with hardened runtime by the identified Shapr3D developer team, and `get-task-allow` is false. Evidence: `ev_5064e905aaeb5e5718eba6b94135a5952384c4179d8dcd5247040102cff288e7`.

## Inferences suitable for clean-room use

- The package identity is strong enough to bind later runtime observations to an exact version and build.
- Public Shapr3D documentation remains the authoritative evidence for advertised Automatic Line/Arc, constraints, splines and snapping behavior until a bounded runtime scenario is recorded.
- Our product should copy neither code nor visual assets. The reusable idea is a compact workflow: live geometry classification, visible snap/constraint hints, one-tap override and explicit closed-profile feedback.

## Unknowns

- Native string/procedure searches did not complete because Hopper exceeded REA's startup-analysis timeout on the large executable.
- No claim is made about Shapr3D's internal classification algorithm, snap priority, thresholds or runtime code paths.
- No runtime scenario, account sign-in, document access or network capture was performed.

