# Findings

## Observations

- REA opened the official macOS trial DMG as a shipped archive. Artifact SHA-256: `e5640499d3d790b34fccc1180b39b3e213bd13255555003701eb316b4ac94a45`.
- The complete package inventory contains 2,749 content-addressed nodes, 2,931 path occurrences and 2,860 edges, with no integrity contradictions. Evidence: `ev_29fe0174e9ba5d711c86d53473020e393ff60a866be7a2453e0d323d020b98a9` and parent `ev_92d28c0a8293558e436fe0915862abdff5d082c8f17d7c3b113bf7ed7efab0a4`.
- The DMG contains `QCAD.app`. Its recorded main executable is an unencrypted Mach-O at `QCAD.app/Contents/MacOS/QCAD`; the bundle also carries Qt frameworks. Evidence: `ev_0547d51494ef7f9e1d8e71167580f4b256173b3fdea6c45bf23c1aa322fd6b1a`.

## Clean-room decision

QCAD Community Edition has an official public source repository. For line/arc/spline geometry, snapping and profile behavior, inspect that public source and the official manual instead of decompiling the trial binary. The trial package remains useful as version and packaging evidence, not as a source of proprietary code or assets.

## Public-source observations

- The inspected public-source revision is `f0b35cb4ff79613693bdc0c0bcbf723f445f71ac` from the official `qcad/qcad` repository. The repository declares GPL-3.0 with optional exceptions, so it is treated as reference evidence rather than code to copy into this application.
- `RPolyline` separates logical closure from geometric closure. A profile can be accepted as geometrically closed when the start-to-end distance is below a supplied tolerance, then normalized into a logically closed representation. This supports a clean-room requirement for explicit closure state plus a tolerance-based “snap closed” repair.
- Polyline length includes the last-to-first segment only when the profile is logically closed. This supports computing and displaying the closing segment explicitly rather than silently assuming it.
- The public implementation exposes arc sector area and circular-segment area as distinct concepts. The circular-segment contribution is based on `r²(θ − sin θ)/2`; this is consistent with integrating an exact circular arc rather than flattening every arc to many short chords.
- Polygon centroid code uses the signed cross-product accumulation used by the shoelace formula. This supports an independent polygonal cross-check for our Green-theorem area result.
- Snap range is evaluated in 2D view coordinates for a three-dimensional view, while ordinary 2D views use model-space distance. This supports using a screen-space capture radius for touch stability while retaining model-space tolerances for measurement validity.

## Clean-room requirements derived from the observations

1. Keep `open`, `near start`, and `closed` as separate profile states.
2. Show the proposed closing segment and its length before accepting closure.
3. Use exact line and circular-arc area integrals; use adaptive numerical integration only for splines.
4. Cross-check the final result with an independently tessellated shoelace calculation and flag disagreement above tolerance.
5. Separate the touch-friendly screen-space snap radius from the metric closure/error tolerance.

## Unknowns

- Runtime snap priority, hysteresis and visual timing were not observed.
- The package inventory alone does not establish which code paths execute for a drawing operation.
- Professional-only behavior may differ from the public Community Edition source.
- The concrete polyline-area proxy is not present in the inspected Community Edition files, so its production implementation is not claimed.
