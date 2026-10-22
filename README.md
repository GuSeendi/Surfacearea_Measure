# SurfaceMeasure — พื้นที่เงา 2D

แอป iPhone + LiDAR สำหรับวัดพื้นที่ฉายสองมิติของขอบชิ้นงานบนระนาบอ้างอิงที่ผู้ใช้ล็อกไว้ แอปไม่ได้คำนวณพื้นที่ผิวสามมิติ

## นิยามการวัด

1. LiDAR หาตำแหน่งขอบชิ้นงานเป็นจุด 3D
2. ทุกจุดถูกฉายตั้งฉากลงระนาบ 2D เดียวกัน แม้ความลึกจริงของจุดจะแตกต่างกัน
3. ตัวอย่างระหว่างจุดถูก fit เป็นเส้นตรงหรือ circular arc
4. ขอบต้องปิดและต้องไม่ตัดหรือทับกัน
5. พื้นที่คำนวณจาก Green's theorem โดยใช้สูตร exact สำหรับ line และ arc

ผลลัพธ์จึงเทียบเท่าพื้นที่ของเงาที่เกิดจากแสงตั้งฉากกับระนาบอ้างอิง

## Workflow

1. เล็งกลางชิ้นงานจน tracking และ depth เป็นสีเขียว
2. กด `ล็อกระนาบเงา`
3. วางจุดเริ่ม แล้วเคลื่อนเป้าตามขอบชิ้นงาน
4. กด `เพิ่มจุด` ที่ปลายด้าน มุม หรือช่วงโค้งสำคัญ
5. ใช้โหมด `อัตโนมัติ`, `เส้นตรง` หรือ `เส้นโค้ง` เพื่อควบคุมการ fit
6. กลับใกล้จุดเริ่มจนเส้นเป็นสีเขียว แล้วกด `ปิดพื้นที่`
7. ตรวจพื้นที่ เส้นรอบรูป ความยาวแต่ละด้าน และ uncertainty โดยประมาณ

## Architecture

- `ARSessionController`: session lifecycle, plane lock, camera-motion tracking, 3D-to-2D projection and measurement state
- `DepthSampler`: robust 5×5 center depth sample with confidence filtering and camera-intrinsic unprojection
- `TemporalPointFilter`: multi-frame endpoint stabilization with robust spike and motion rejection
- `CaptureQualityEvaluator`: tracking, depth, standoff, speed, angle and thermal gates
- `ProfileFitter`: bounded-sample line/arc fitting with explicit override
- `ProfileValidator`: closure, crossing and overlap checks
- `ShadowAreaCalculator`: exact Green-integral area and perimeter
- `BoundaryOverlayRenderer`: low-overhead `CAShapeLayer` overlay projected through RealityKit

## Performance decisions

- Depth/pose UI processing is capped at 30 Hz.
- Arc preview fitting is capped at 15 Hz.
- Each active side retains at most 512 spatially reduced observations.
- Geometry rendering updates existing layers instead of recreating RealityKit entities.
- Measurement and display use the same compact 2D entities; no 3D mesh reconstruction or cloud processing is required.

## Build and checks

```sh
xcodebuild -project SurfaceMeasure.xcodeproj \
  -target SurfaceMeasure \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

```sh
xcrun swiftc \
  SurfaceMeasure/Models/PlanarGeometry.swift \
  SurfaceMeasure/Models/MeasurementState.swift \
  SurfaceMeasure/Services/ProfileFitter.swift \
  SurfaceMeasure/Services/ProfileValidator.swift \
  SurfaceMeasure/Services/ShadowAreaCalculator.swift \
  Tests/ShadowAreaEngineCheck.swift \
  -o /tmp/shadow-area-check
/tmp/shadow-area-check
```

The app requires an iPhone with LiDAR and iOS 18 or newer. Simulator builds verify compilation and UI contracts but cannot validate LiDAR behavior.

For a locally signed development build, iOS may require one manual trust action before first launch: `Settings → General → VPN & Device Management → Developer App → Trust`.

## Accuracy status

The geometry engine is deterministically checked, but sensor accuracy has not yet completed the physical protocol in `VALIDATION.md`. Until that protocol passes, results remain engineering estimates and the app must not claim certified or traceable accuracy.
