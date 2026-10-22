# Evidence Ledger

## Current Status

| Target | Public evidence | Local artifact | REA evidence | Status |
|---|---:|---:|---:|---|
| Apple Measure 175.100.3.0.1 | Yes | Installed on iPhone | Yes, lifecycle only | Controlled launch recorded; stock iOS requires Frida Gadget for attach |
| Shapr3D | Yes | Yes | Yes | Official DMG identity and package evidence recorded; native feature search pending provider cleanup |
| SOLIDWORKS | Yes | No | No | Public behavior documented |
| magicplan 2026.41.0 (202641000) | Yes | Installed on iPhone | Yes, lifecycle only | Launch recorded; runtime internals blocked by stock-iOS attach boundary |
| Polycam 7.0.6 (631) | Yes | Installed on iPhone | Yes, lifecycle only | Launch recorded; runtime internals blocked by stock-iOS attach boundary |
| Twindo 1.0.90 (258) | Yes | Installed on iPhone | Yes, launch request only | Launch accepted, but process was not retained; no matching crash log found |
| Leica DISTO Plan 3.3.0 (1831) | Yes | Installed on iPhone | Yes, lifecycle only | Launch recorded; runtime internals blocked by stock-iOS attach boundary |
| SurfaceMeasure 0.1.0 (1) | N/A | Developer app installed on iPhone | Yes, control only | Control proved Frida needs Gadget on this jailed iOS device |
| QCAD 3.33.1 | Yes | Yes | Yes | Official trial DMG inventoried; official Community source reviewed at a pinned commit |
| SketchUp 26.2.242 | Yes | Yes | Blocked | Official DMG identity verified locally; REA package intake blocked by retained Hopper cleanup |
| Apple ARKit/Vision/RoomPlan | Yes | SDK only | Not needed for public API | API capability documented |

## REA Readiness Check

- Date: 2026-10-21
- REA CLI package: `rea-agents 6.7.0`
- REA MCP registration for Codex: configured and aligned
- Codex config: `/Users/seenpeep/.codex/config.toml`
- Config backup: `/Users/seenpeep/.codex/config.toml.rea.backup`
- REA skill: version 42, installed and aligned at `/Users/seenpeep/.agents/skills/reverse-engineer-anything`
- Native analysis provider: Hopper installed and healthy at `/Users/seenpeep/Applications/Hopper Disassembler.app`
- MCP verification: successful protocol handshake with server `rea 6.7.0`
- Ghidra, IDA, JADX and Kuna remain optional, caller-supplied providers and are not configured
- Active Codex session successfully loaded and used the REA tools.
- Official artifacts are stored temporarily under `/private/tmp/surface_measure_rea_targets/`; binaries are not committed to this repository.
- Shapr3D native deep indexing exceeded the provider startup window and left the active MCP connection with stale cleanup state. The tool-owned Hopper processes were terminated and its temporary runtime directory was moved to Trash; a fresh MCP connection is still required before another REA target. Package, plist, signature and architecture Evidence remain valid; native procedure/string findings are not claimed.
- SketchUp was inspected with read-only macOS utilities only after REA refused a new target due to that stale cleanup state. These observations are not labeled as REA Evidence.
- Apple Measure, magicplan, Polycam and DISTO Plan were observed through bounded controlled launches. The evidence establishes launch lifecycle only, not UI behavior or internal implementation.
- A Frida control attach to the developer-owned SurfaceMeasure app returned the explicit platform blocker: a jailed iOS device requires Frida Gadget. The same provider could not attach to Apple Measure, magicplan, Polycam or DISTO Plan. This is a device/instrumentation boundary, not evidence that any framework or feature is absent.
- Twindo accepted the launch request but did not remain in the process list. No matching system crash log was found in the bounded target-only search, so the reason remains unknown and is not labeled a crash.
- Evidence IDs: Apple Measure `ev_f5b774eb8daafbc530c2a14ff6ecf483652fe7c2054e67c181d5763b0e018473`; magicplan `ev_0e522d95912b007fdc955bf77d5aac875fd48c21a2f7e1f5f2b4ca15a6cc90c5`; Polycam `ev_9cb08bdc37c24d2c15618013e6a4032495cd5a7e03377cdff40a17a586725b11`; Twindo `ev_a060f205a96fc997fd67411cf7c08abf0b20bb2609ae45bdae0be59c84080373`; DISTO Plan `ev_627dc6a78795cad542d9b2788b1877d58c77a5ed677e775087ab662a7d926b1d`; SurfaceMeasure control `ev_3ea182b6faec1a5aa42aaaf4865d31c1b44e6ab7ba9225823996133f52acd1cd`.

## Evidence Rules

1. Public documentation establishes advertised behavior, not implementation details.
2. Static binary evidence establishes packaged code/resources, not runtime execution.
3. Runtime evidence establishes only the exact scenario that was observed.
4. Absence in a bounded search does not prove a feature does not exist.
5. Every later REA finding must include target version, digest, Evidence ID, confidence, limitations and unresolved questions.
6. Never store credentials, license material, personal data, proprietary assets or extracted source in this repository.
7. A feature may enter the implementation backlog only when it can be expressed as an independent clean-room requirement.

## Public Sources

### Apple

- https://support.apple.com/en-mide/guide/iphone/iphd8ac2cfea/27/ios/27
- https://developer.apple.com/documentation/arkit/arframe/scenedepth
- https://developer.apple.com/documentation/arkit/environmental-analysis
- https://developer.apple.com/documentation/vision/detectcontoursrequest
- https://developer.apple.com/documentation/roomplan

### Shapr3D

- https://support.shapr3d.com/hc/en-us/articles/7770681244316-Automatic-Line-Arc
- https://support.shapr3d.com/hc/en-us/articles/12469721233692-Sketch-constraints-and-splines
- https://support.shapr3d.com/hc/en-us/articles/7873946289564-Snapping-Options
- https://support.shapr3d.com/hc/en-us/articles/18816009328284-Sketching-in-Shapr3D

### SOLIDWORKS

- https://help.solidworks.com/2022/english/SolidWorks/acadhelp/c_Automatic_Sketch_Operations_AcadHelp.htm
- https://help.solidworks.com/2024/English/SolidWorks/Sldworks/c_Description_of_Sketch_Relations.htm
- https://help.solidworks.com/2026/english/SolidWorks/sldworks/r_Spline_Tools_Toolbar.htm
- https://help.solidworks.com/2024/English/SolidWorks/Sldworks/c_Fit_Splines.htm
- https://help.solidworks.com/2022/english/SolidWorks/sldworks/HIDD_SKETCH_GEOM_DIAGNOSTICS_impexp.htm
- https://help.solidworks.com/2021/english/SolidWorks/sldworks/c_error_message_check_sketch.htm
- https://help.solidworks.com/2023/english/Solidworks/sldworks/c_Shaded_Sketch_Contour.htm
- https://help.solidworks.com/2026/english/SolidWorks/sldworks/c_section_properties.htm

### Scanning and measurement products

- https://help.magicplan.app/scan-a-room-in-seconds-using-lidar
- https://help.magicplan.app/auto-scan-your-floor-plan
- https://help.magicplan.app/how-accurate-is-magicplan
- https://help.magicplan.app/autoscan-faq
- https://learn.poly.cam/hc/en-us/articles/48565771018772-Which-Capture-Mode-Should-I-Use
- https://learn.poly.cam/hc/en-us/articles/48338504343188-How-to-Capture-As-Built-Drawings
- https://learn.poly.cam/hc/en-us/articles/27425185907348-How-to-Use-Object-Mode
- https://learn.poly.cam/hc/en-us/articles/48336423303572-How-to-3D-Scan-Mechanical-Parts
- https://www.twindo.com/support/tutorial-how-to-scan-a-room-with-canvas/
- https://leica-geosystems.com/en-gb/products/disto-and-leica-lino/learning-centre-for-disto-and-leica-lino
- https://shop.leica-geosystems.com/sites/default/files/2024-04/03_DISTO%20Plan%20App%20-%20Measure%20Plan_EN.pdf
- https://shop.leica-geosystems.com/sites/default/files/2024-04/06_DISTO%20Plan%20App%20-%20Smart%20Room_EN.pdf
