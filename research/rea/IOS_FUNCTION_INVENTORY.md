# Installed iOS App Function Inventory

This inventory covers functions relevant to SurfaceMeasure. `PUBLIC` means documented by the vendor; `OBSERVED` means established in the bounded device scenario; `UNKNOWN` means that the internal mechanism was not observed.

## Apple Measure 175.100.3.0.1

- `PUBLIC` Slowly scans the nearby scene before measurement.
- `PUBLIC` Automatically recognizes a rectangular object's edges and reports dimensions/area.
- `PUBLIC` Manual point-to-point measurement using a center-screen dot and start/end actions.
- `PUBLIC` Multiple measurements before clearing the session.
- `PUBLIC` Automatic straight-edge guide lines on supported devices.
- `PUBLIC` Ruler detail view when moving closer to a completed measurement.
- `PUBLIC` Captures a photo with measurement context.
- `PUBLIC` Apple describes measurements as approximate and recommends well-defined objects roughly 0.5–3 m away.
- `OBSERVED` Installed identity, successful launch and running process.
- `UNKNOWN` Reticle filtering, edge confidence, depth fusion, snapping thresholds, hysteresis and failure-state logic.

Source: https://support.apple.com/en-mide/guide/iphone/iphd8ac2cfea/27/ios/27

## magicplan 2026.41.0

- `PUBLIC` Manual-Scan with Corner Mode and LiDAR Wall Mode.
- `PUBLIC` AR corner marking, white aiming grid and automatic/manual corner placement.
- `PUBLIC` Automatic wall recognition with green captured state and check mark.
- `PUBLIC` Switches from Wall Mode to Corner Mode when a wall is occluded or cannot be detected.
- `PUBLIC` Calibration guidance, ceiling-height capture, door/window capture, undo and in-scan photos.
- `PUBLIC` Auto-Scan using RoomPlan for multiple rooms, walls, openings, furniture and other objects.
- `PUBLIC` Live 2D/3D floorplan view, attached scan photos, review, confirm, discard/rescan and post-scan configuration.
- `PUBLIC` Green successful walls and orange incomplete walls; unsuccessful closure may prevent 2D rendering.
- `PUBLIC` Manual workflow is recommended for difficult cases such as open plans, stairwells, glass walls and heavy construction.
- `OBSERVED` Installed identity, successful launch and running process.
- `UNKNOWN` Wall/corner thresholds, state machine, sensor filtering, closure criteria and error model.

Sources: https://help.magicplan.app/scan-a-room-in-seconds-using-lidar and https://help.magicplan.app/auto-scan-your-floor-plan

## Polycam 7.0.6

- `PUBLIC` Space, Object, Floorplan, AI Capture and 360 capture modes.
- `PUBLIC` Space Mode produces an aligned 3D scan and measured floorplan products.
- `PUBLIC` Planned capture path and slow perimeter motion.
- `PUBLIC` Live coverage guidance, including highlighted missing zones and visible corner/wall guidance.
- `PUBLIC` Flashlight assistance and guidance to include corners, ceiling and floor.
- `PUBLIC` On-device and cloud processing choices for different scan sizes.
- `PUBLIC` Generated 2D floorplan with toggles for dimensions, furniture, total areas, labels, compass and wall thickness.
- `PUBLIC` Spatial PDF report, manual linear/area measurement and Automeasure.
- `PUBLIC` Comments, sharing and export for CAD/design tools.
- `OBSERVED` Installed identity, successful launch and running process.
- `UNKNOWN` Coverage scoring, drift correction, depth/vision fusion, automatic measurement rules and cloud implementation.

Sources: https://learn.poly.cam/hc/en-us/articles/48565771018772-Which-Capture-Mode-Should-I-Use and https://learn.poly.cam/hc/en-us/articles/48338504343188-How-to-Capture-As-Built-Drawings

## Twindo 1.0.90

- `PUBLIC` LiDAR room scanning on supported iPhone/iPad devices.
- `PUBLIC` Begins at a detail-rich corner and recommends a 5–10 ft standoff.
- `PUBLIC` Slow vertical sweeps combined with small sideways steps in a repeated “fence painting” path.
- `PUBLIC` Continues around perimeter walls and returns to the start before completion.
- `PUBLIC` Avoids stationary pivoting, multi-floor capture and duplicate coverage in one scan.
- `PUBLIC` Uses a modified “J” path for tight spaces.
- `PUBLIC` Downstream product families include measurement reports, 2D plans and multiple Scan-to-CAD outputs.
- `OBSERVED` Installed identity and accepted launch request.
- `OBSERVED` The process did not remain observable; no matching target crash log was found.
- `UNKNOWN` Startup outcome on this device, live quality UI, tracking metrics, completeness logic and processing pipeline.

Source: https://www.twindo.com/support/tutorial-how-to-scan-a-room-with-canvas/

## Leica DISTO Plan 3.3.0

- `PUBLIC` Point, Line and Area measurement entities.
- `PUBLIC` Rough sketch creation followed by precise dimension assignment.
- `PUBLIC` Snapping near an existing point.
- `PUBLIC` 2D/3D views and area/perimeter results.
- `PUBLIC` Irregular-shape measurement by ordered points/segments.
- `PUBLIC` Smart Room workflow with compatible Leica DISTO measurement transfer.
- `PUBLIC` Export/plan workflows for downstream documentation and CAD use.
- `OBSERVED` Installed identity, successful launch and running process.
- `UNKNOWN` Snap priority/tolerance, Bluetooth protocol details, dimension reconciliation, closure handling and numerical methods.

Sources: https://shop.leica-geosystems.com/sites/default/files/2024-04/03_DISTO%20Plan%20App%20-%20Measure%20Plan_EN.pdf and https://shop.leica-geosystems.com/sites/default/files/2024-04/06_DISTO%20Plan%20App%20-%20Smart%20Room_EN.pdf

## Cross-app functions worth implementing

| Function | Best reference pattern | SurfaceMeasure requirement |
|---|---|---|
| Aim without finger occlusion | Apple Measure | Center reticle plus magnifier |
| Assisted/manual fallback | magicplan | Preserve confirmed geometry when changing capture method |
| Coverage and motion coaching | Polycam + Twindo | Per-frame distance/angle/speed/tracking checks and plane-cell heatmap |
| Explicit geometry types | DISTO Plan + CAD references | Point, line, circular arc, free curve and closing segment |
| Trustworthy closure | magicplan + CAD references | Metric gap/topology checks; no silent large-gap closure |
| Independent scale check | DISTO Plan | Optional tape/laser reference length |
| Measurement audit trail | Apple Measure + Polycam | Snapshot, raw samples, fitted entities, confidence and export |

## Boundary

The inventory is broad for measurement/scanning functions relevant to this product, but it is not a claim of exhaustive private internals. The current stock-iOS device blocks process instrumentation without Frida Gadget, and no App Store package was decrypted, modified or re-signed.
