# Findings

## Observations

- CoreDevice identified Polycam 7.0.6 build 631 with bundle identifier `ai.polycam.polycam` on the paired iPhone 16 Pro.
- REA launched the bundle successfully under bounded process capture; exit code was 0 and cleanup was verified. Evidence: `ev_9cb08bdc37c24d2c15618013e6a4032495cd5a7e03377cdff40a17a586725b11`.
- CoreDevice subsequently observed the Polycam process running.
- REA's Frida provider could not attach and returned `capability_unavailable`.

## Public functional evidence

- Polycam documents Space, Object, Floorplan, AI Capture and 360 capture modes. Its LiDAR Space workflow can produce a mesh, 3D floorplan and measured 2D floorplan; Floorplan capture follows the perimeter.
- Its as-built workflow emphasizes deliberate path planning, slow movement, visible coverage, revisiting missing regions, review, linear/area measurement, annotation and export.

## Clean-room implications

- SurfaceMeasure needs a plane-cell coverage map and explicit low-confidence spans, but not a full object mesh.
- A short movement coach should continuously combine distance, angular view, motion speed and tracking/depth confidence.

## Unknowns

- Internal coverage scoring, filtering, on-device/cloud division and automatic-measurement algorithms were not observed.
- No camera scan, saved capture, account, file or network behavior was accessed.
