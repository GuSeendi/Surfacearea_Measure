# Runtime Scenarios

## Scenario A — Controlled launch

- Date: 2026-10-21 (Asia/Bangkok)
- Device: paired iPhone 16 Pro
- Action: launch bundle `com.apple.measure` through CoreDevice under REA process capture
- Result: launch succeeded; command exit code 0
- Evidence: `ev_f5b774eb8daafbc530c2a14ff6ecf483652fe7c2054e67c181d5763b0e018473`
- Coverage: application lifecycle only; no UI actions, camera measurements, network observation or filesystem scope

## Scenario B — Frida attach

- Target: the running Apple Measure device process identified through CoreDevice
- Result: REA returned `capability_unavailable` because Frida could not attach
- Control: SurfaceMeasure 0.1.0 returned the explicit requirement for Frida Gadget on jailed iOS; Evidence `ev_3ea182b6faec1a5aa42aaaf4865d31c1b44e6ab7ba9225823996133f52acd1cd`
- Interpretation: platform-blocked instrumentation, not evidence that a feature or framework is absent
