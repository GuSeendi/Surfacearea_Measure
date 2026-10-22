# Findings

## Observations

- CoreDevice identified Apple Measure version 175.100.3.0.1 with bundle identifier `com.apple.measure` on the paired iPhone 16 Pro.
- REA executed a bounded controlled-replay scenario that launched `com.apple.measure`. The device tunnel and developer disk-image services were acquired, the launch request succeeded, the command exited with code 0, and REA reported cleanup as verified. Evidence: `ev_f5b774eb8daafbc530c2a14ff6ecf483652fe7c2054e67c181d5763b0e018473`.
- After launch, CoreDevice observed the Measure executable running as a device process.
- REA's Frida provider could not attach to that process and returned `capability_unavailable`.
- A control attach to the developer-owned SurfaceMeasure app produced the explicit blocker `Need Gadget to attach on jailed iOS`, showing that the current limitation is the stock-iOS instrumentation boundary rather than evidence specific to Measure. Control Evidence: `ev_3ea182b6faec1a5aa42aaaf4865d31c1b44e6ab7ba9225823996133f52acd1cd`.

## Inferences

- The current host-device connection is sufficient for controlled app launch and process observation.
- It is not sufficient for internal instrumentation without Frida Gadget. Apple Measure cannot be modified or re-signed within this clean-room scope. No conclusion about LiDAR sampling, filtering, reticle stabilization or snap thresholds follows from the launch evidence.

## Unknowns

- Loaded private/public frameworks inside the Measure process were not observed through REA.
- No camera-motion, start/end placement, edge-guide, tracking-loss or relocalization scenario was captured.
- Internal algorithms, thresholds and data flow remain unknown.
