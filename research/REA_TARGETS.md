# REA Target Intake

เอกสารนี้กำหนดสิ่งที่ต้องมีเพื่อวิเคราะห์พฤติกรรมเพิ่มเติมด้วย REA โดยไม่ขยายขอบเขตไปยังข้อมูลหรือโค้ดที่ไม่จำเป็น

## Target Order

1. Apple Measure runtime บน iPhone ที่ผู้ใช้เป็นเจ้าของ
2. Shapr3D package/runtime เวอร์ชันที่ผู้ใช้ใช้งานได้ถูกต้อง
3. magicplan runtime
4. Polycam runtime
5. Canvas runtime
6. Leica DISTO Plan runtime
7. SOLIDWORKS installer/binary และ runtime บนเครื่อง Windows ที่ได้รับอนุญาต

## Completed Static Intake

- Shapr3D 26.180.0 (11926): official macOS DMG inventoried with REA; plist, signature and architectures recorded. Native deep indexing timed out and is not claimed.
- QCAD 3.33.1: official macOS trial DMG inventoried with REA; official public Community source pinned and reviewed as reference evidence.
- SketchUp 26.2.242: official macOS DMG downloaded and identity-checked read-only. REA intake remains pending because the active Hopper connection retained an unconfirmed cleanup state.

Static intake does not replace runtime scenarios for camera movement, snap hysteresis, haptics or visual timing.

## Required Intake Per Target

- Human-readable app name
- Exact version/build
- Platform and OS version
- Artifact absolute path หรือ runtime target ที่เปิดอยู่
- Proof of scope: ผู้ใช้เป็นเจ้าของหรือได้รับอนุญาตให้วิเคราะห์
- Questions to answer
- Allowed runtime actions
- Explicit exclusions เช่น login, network capture, cloud content หรือ licensed datasets

## Scenario Checklist

### Measurement placement

- Start-point acquisition
- Live preview during camera movement
- Endpoint confirmation
- Undo/redo behavior
- Loss of tracking and relocalization
- Measurement persistence after leaving frame

### Geometry recognition

- Straight line recognition
- Arc recognition
- Spline/control-point workflow
- Segment switching gesture
- Snap priority and release behavior
- Tangency and coincidence feedback

### Profile completion

- Closing tolerance
- Gap and overlap presentation
- Self-intersection handling
- Filled-area indication
- Error repair sequence
- Area/perimeter update timing

### Capture coaching

- Coverage colors
- Missing-data warnings
- Movement-speed warnings
- Lighting/texture warnings
- Haptics and sounds
- Recovery after interruption

## Output Contract

REA findings should be saved under `research/rea/<target>/<version>/` as:

- `TARGET.json` — identity, version, SHA-256 and scope
- `QUESTIONS.md` — investigation checklist
- `FINDINGS.md` — observations, inferences, unknowns and Evidence IDs
- `SCENARIOS.md` — exact runtime actions and observed results
- `LIMITATIONS.md` — bounded searches and unresolved items

Do not store extracted proprietary source, copyrighted assets, credentials, license files or private network payloads.
