# Findings

## Observations

- CoreDevice identified magicplan 2026.41.0 build 202641000 with bundle identifier `com.sensopia.magicplan` on the paired iPhone 16 Pro.
- REA launched the bundle successfully under bounded process capture; exit code was 0 and cleanup was verified. Evidence: `ev_0e522d95912b007fdc955bf77d5aac875fd48c21a2f7e1f5f2b4ca15a6cc90c5`.
- CoreDevice subsequently observed the magicplan process running.
- REA's Frida provider could not attach and returned `capability_unavailable`.

## Public functional evidence

- magicplan documents manual LiDAR capture with Corner and Wall modes, capture-status feedback, and switching to Corner mode when Wall mode cannot identify a wall.
- Its Auto-Scan uses a multi-room/object scan with a review stage. Documentation marks valid/incomplete capture states and says automatic closure needs sufficient scan data; otherwise the user must rescan or discard.

## Clean-room implications

- SurfaceMeasure should expose one assisted mode with an immediate manual fallback, preserve confirmed segments during the switch, and never silently close a large missing span.
- Completion color must represent evidence quality, not merely elapsed capture time.

## Unknowns

- Internal frameworks, thresholds, filters, state transitions and algorithms were not observed.
- No camera scan, project, account, file or network behavior was accessed.
