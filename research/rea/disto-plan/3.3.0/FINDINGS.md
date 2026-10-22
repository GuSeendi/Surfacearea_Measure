# Findings

## Observations

- CoreDevice identified Disto Plan 3.3.0 build 1831 with bundle identifier `com.leica-geosystems.disto-plan` on the paired iPhone 16 Pro.
- REA launched the bundle successfully under bounded process capture; exit code was 0 and cleanup was verified. Evidence: `ev_627dc6a78795cad542d9b2788b1877d58c77a5ed677e775087ab662a7d926b1d`.
- CoreDevice subsequently observed the Disto Plan process running.
- REA's Frida provider could not attach and returned `capability_unavailable`.

## Public functional evidence

- Leica documents Point, Line and Area measurement entities, snapping near existing points, 2D/3D views, and area/perimeter results.
- Its workflows separate a rough sketch from precise dimensions supplied by a DISTO laser meter.

## Clean-room implications

- SurfaceMeasure should keep observed geometry separate from confirmed dimensions and optionally accept one trusted reference length for scale verification.
- The side list should expose each entity type, measured length, confidence and whether its value came from vision/depth, manual correction or an external reference.

## Unknowns

- Internal snap thresholds, dimension-reconciliation rules, error handling and algorithms were not observed.
- No pairing, laser transfer, project, file or network behavior was accessed.
