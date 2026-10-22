# iOS Measurement-App REA Matrix

Date: 2026-10-21 (Asia/Bangkok)  
Device: paired iPhone 16 Pro, stock/jailed iOS  
Scope: installed-app identity, bounded launch lifecycle, target-only process observation, and a bounded attach attempt. No accounts, existing projects, camera captures, files, network traffic, decryption, DRM bypass or re-signing.

## Evidence matrix

| Target | Installed identity | Controlled result | Internal runtime evidence | Useful public function families |
|---|---|---|---|---|
| Apple Measure | 175.100.3.0.1, `com.apple.measure` | Launched and process observed; `ev_f5b774eb8daafbc530c2a14ff6ecf483652fe7c2054e67c181d5763b0e018473` | Blocked: stock iOS requires Gadget | center reticle, edge guides, manual endpoints, ruler detail, measurement photo |
| magicplan | 2026.41.0 (202641000), `com.sensopia.magicplan` | Launched and process observed; `ev_0e522d95912b007fdc955bf77d5aac875fd48c21a2f7e1f5f2b4ca15a6cc90c5` | Blocked: stock iOS requires Gadget | assisted/manual fallback, valid/incomplete states, review/rescan, guarded closure |
| Polycam | 7.0.6 (631), `ai.polycam.polycam` | Launched and process observed; `ev_9cb08bdc37c24d2c15618013e6a4032495cd5a7e03377cdff40a17a586725b11` | Blocked: stock iOS requires Gadget | capture modes, coverage guidance, path planning, review, linear/area measurement, export |
| Twindo | 1.0.90 (258), `com.twindo.mobile` | Launch accepted but process not retained; `ev_a060f205a96fc997fd67411cf7c08abf0b20bb2609ae45bdae0be59c84080373` | Not available; startup outcome unknown | slow perimeter path, stable standoff, return to start, duplicate-coverage avoidance |
| DISTO Plan | 3.3.0 (1831), `com.leica-geosystems.disto-plan` | Launched and process observed; `ev_627dc6a78795cad542d9b2788b1877d58c77a5ed677e775087ab662a7d926b1d` | Blocked: stock iOS requires Gadget | Point/Line/Area entities, point snap, rough sketch plus trusted dimensions, area/perimeter |
| SurfaceMeasure control | 0.1.0 (1), `com.seenpeep.surfacemeasure.l4snj5kt4n` | Launched; `ev_3ea182b6faec1a5aa42aaaf4865d31c1b44e6ab7ba9225823996133f52acd1cd` | Explicit blocker: `Need Gadget to attach on jailed iOS` | establishes the platform limitation; no competitor inference |

## What is established

- All five requested reference applications were identified by bundle/version on the device and received a bounded launch attempt.
- Four remained observable as processes. Twindo did not, and no matching crash log was found in the bounded search.
- The current REA path cannot inspect loaded modules, calls or algorithms on this stock iPhone without Frida Gadget. The control app proves this is not an Apple-Measure-only restriction.
- Public documentation supports the functional inventory, but does not reveal proprietary implementation details.

## Clean-room synthesis for SurfaceMeasure

1. One `Assisted Trace` mode: center reticle, automatic line/arc proposal, and a one-tap manual override.
2. Freeze a local 2D plane after confirmation. Project all accepted points to that plane even when raw depth differs, while rejecting samples whose off-plane residual exceeds the uncertainty gate.
3. Track camera pose, distance to plane, viewing angle, motion speed, AR tracking state and depth confidence every frame. Coach `closer`, `farther`, `slower`, `more frontal`, or `revisit orange span`.
4. Maintain a plane-cell evidence map and a per-segment confidence trace. Never average duplicated/relocalized samples blindly.
5. Preserve raw samples and fitted line/arc/spline entities separately. Allow refit, type override and endpoint edits.
6. Snap screen-space for usability but validate closure in metric plane coordinates. Large gaps require explicit user confirmation.
7. Validate topology before area calculation: open gap, overlap, near-zero segment, self-intersection, multiple loops and low-confidence spans.
8. Calculate line/arc terms analytically with Green's theorem; integrate splines adaptively and cross-check with a tessellated shoelace result.
9. Report area, perimeter, every segment length and uncertainty. Optionally accept one trusted tape/laser dimension as an independent scale check.
10. Add a debug-only observability layer to our own build: timestamped pose, plane transform, raycast/depth sample, confidence, fit residual, closure error and repeatability run ID.

## Remaining boundary

“Every internal function” is not established. Achieving that would require an authorized unpacked artifact or modifying/re-signing App Store packages to embed instrumentation, which was not performed. The safe high-value next step is to instrument SurfaceMeasure itself and run repeatable physical test paths against known reference shapes.
