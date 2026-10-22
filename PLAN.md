# SurfaceMeasure 2D Shadow-Area Plan

## Product boundary

- Measure one closed projected silhouette on one locked 2D plane.
- Support connected straight lines and circular arcs.
- Preserve depth only long enough to recover a 3D boundary point; orthogonally project that point to the locked plane before geometry and area calculation.
- Do not reconstruct or sum 3D surface triangles.
- Never silently close a large gap or accept crossing/overlapping boundaries.

## Implemented foundation — 0.2.0

- Camera permission and AR/LiDAR capability checks.
- Raw Scene Depth sampling with confidence filtering.
- Plane lock from AR raycast with camera-facing fallback.
- Continuous tracking, distance, speed, angle and thermal quality gates.
- Stable local plane coordinates that remain fixed while the user walks.
- One guided tracing screen with center reticle and haptic feedback.
- Automatic, forced-line and forced-arc modes.
- Bounded observation storage and real-time line/arc preview.
- Undo, reset, metric closure tolerance and closed-profile fill.
- Self-intersection and collinear-overlap rejection.
- Exact line/arc Green's-theorem area and analytic perimeter.
- Estimated uncertainty, per-side lengths and shareable text result.
- Deterministic checks for rectangle, orientation, circle, crossing, overlap and fit classification.
- Robust multi-frame endpoint stabilization that rejects isolated depth spikes and moving reticles.

## Precision phase

1. Record debug-only frame telemetry on the developer build: pose, tracking state, depth/confidence samples, plane transform, speed, angle, fit residual and closure gap.
2. Quantify and tune the implemented temporal endpoint filter on physical reference targets.
3. Quantify lateral point uncertainty from known targets at multiple distances and viewing angles instead of relying on provisional constants.
4. Detect AR relocalization jumps and freeze measurement input until the locked plane is re-established within tolerance.
5. Add a reference-length verification option for tape/laser ground truth without modifying the measured silhouette.
6. Compare forward and reverse traces and warn when the resulting areas disagree beyond the validated repeatability threshold.

## Geometry phase

1. Add editable endpoints and arc handles after closure.
2. Add cubic Bézier/B-spline only after an exact/adaptive Green integral and stable fitting tests exist.
3. Support holes as explicit nested loops; do not infer them automatically.
4. Add JSON audit export containing the plane, raw observations, fitted entities, residuals and quality metadata.
5. Add SVG/DXF export from local plane coordinates.

## Release gates

- Simulator and iPhoneOS builds pass without compiler errors.
- Deterministic geometry checks pass.
- No accepted profile is open, self-crossing or overlapping.
- Physical validation in `VALIDATION.md` passes for the published size, material, distance and lighting envelope.
- Accuracy and uncertainty text reflects measured validation evidence rather than a marketing target.
- Thermal and long-session profiling on the target iPhone shows no sustained frame backlog or unbounded memory growth.
