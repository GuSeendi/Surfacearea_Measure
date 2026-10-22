# Surface Measure Feature Vault

เอกสารนี้รวบรวมพฤติกรรมและแนวคิดที่เหมาะกับแอปวัดพื้นที่แผ่นข้างวัตถุบน iPhone แบบ clean-room เพื่อใช้เป็นข้อกำหนดในอนาคต ไม่ได้เก็บซอร์สโค้ด ไฟล์ภาพ ไอคอน ข้อความ หรืออัลกอริทึมลับของแอปต้นแบบ

## Product Boundary

- วัดพื้นที่ของ `closed 2D profile` ที่อยู่บนระนาบจริงหนึ่งระนาบ
- ขอบเขตอาจประกอบด้วยเส้นตรง ส่วนโค้งวงกลม และ spline
- LiDAR ใช้ล็อกระนาบ กำหนดสเกล และแปลงตำแหน่งหน้าจอเป็นพิกัดจริง
- กล้อง RGB และ Vision ใช้เสนอขอบ ไม่ใช่ตัดสินแทนผู้ใช้โดยไม่มีการยืนยัน
- ผู้ใช้เป็นผู้เลือกพื้นที่ เริ่มด้าน จบด้าน แก้ไข และสั่งปิดรูป
- ไม่วัดพื้นที่ผิวสามมิติทั้งหมดของวัตถุ

## Evidence Labels

- `PUBLIC`: ยืนยันจากเอกสารหรือคู่มือสาธารณะของผู้ผลิต
- `OBSERVED`: เห็นจาก artifact หรือ runtime ในขอบเขตที่บันทึกไว้
- `DESIGN`: แนวทางที่เราจะสร้างเองจากการรวมหลายรูปแบบการทำงาน
- `REA-PENDING`: ต้องตรวจจาก artifact หรือ runtime ที่ผู้ใช้มีสิทธิ์ใช้งานก่อน
- `REA-BLOCKED`: พยายามตรวจแล้ว แต่ติดขอบเขต platform/artifact ที่ระบุไว้
- `OUT`: ไม่เหมาะกับขอบเขตผลิตภัณฑ์

## 1. Apple Measure Pattern

ต้นทาง: [Apple Measure](https://support.apple.com/en-mide/guide/iphone/iphd8ac2cfea/27/ios/27)

### เก็บมาใช้

- `PUBLIC` เป้ากลางจอเป็นตัวเลือกตำแหน่งแทนการเอานิ้วบังจุดวัด
- `PUBLIC` กดเพิ่มจุดเริ่มและจุดจบ แล้วแสดงความยาวสดระหว่างเคลื่อนกล้อง
- `PUBLIC` สร้างการวัดหลายรายการต่อเนื่องได้
- `PUBLIC` เส้นนำทางปรากฏเมื่อพบขอบตรง
- `PUBLIC` เข้าใกล้เส้นวัดแล้วเปลี่ยนเป็นมุมมองไม้บรรทัดละเอียด
- `PUBLIC` ถ่ายภาพพร้อมผลการวัดเพื่อบันทึกหลักฐาน
- `DESIGN` endpoint ของด้านก่อนหน้ากลายเป็น start point ของด้านถัดไปโดยอัตโนมัติ
- `DESIGN` ปุ่มหลักหนึ่งปุ่มเปลี่ยนตามสถานะ: `เริ่มด้าน` → `จบด้าน` → `ปิดพื้นที่`
- `DESIGN` ใช้ haptic เมื่อวางจุดสำเร็จหรือ snap เข้าจุดเดิม

### ไม่เก็บมาใช้ตรง ๆ

- `OUT` การตรวจสี่เหลี่ยมอัตโนมัติเป็นแกนหลัก เพราะชิ้นงานไม่ใช่สี่เหลี่ยม
- `OUT` การวัดเพียงระยะจุดต่อจุดโดยไม่มีระนาบที่ล็อกแล้ว
- `OUT` การแสดงค่าที่ดูแม่นยำเกินคุณภาพข้อมูลจริง

## 2. Shapr3D Sketch Pattern

ต้นทาง: [Automatic Line/Arc](https://support.shapr3d.com/hc/en-us/articles/7770681244316-Automatic-Line-Arc), [Sketch constraints and splines](https://support.shapr3d.com/hc/en-us/articles/12469721233692-Sketch-constraints-and-splines), [Snapping Options](https://support.shapr3d.com/hc/en-us/articles/7873946289564-Snapping-Options), [Sketching](https://support.shapr3d.com/hc/en-us/articles/18816009328284-Sketching-in-Shapr3D)

### Geometry entities

- `PUBLIC` Line
- `PUBLIC` Circular arc
- `PUBLIC` Circle และ ellipse สำหรับกรณีพิเศษ
- `PUBLIC` Spline พร้อม control points
- `PUBLIC` Closed sketch profile
- `DESIGN` Raw sample cloud เป็นข้อมูลชั่วคราว ไม่ใช่ geometry สุดท้าย
- `DESIGN` ทุก entity เก็บพิกัดใน local plane coordinates `(u, v)` หน่วยเมตร

### Intent recognition

- `PUBLIC` โหมดอัตโนมัติแยก gesture ระหว่าง line และ arc
- `DESIGN` เมื่อกด `จบด้าน` ให้ทดสอบโมเดลตามลำดับ line → circular arc → cubic Bézier/B-spline
- `DESIGN` เลือกโมเดลง่ายที่สุดที่ residual error ต่ำกว่า tolerance
- `DESIGN` แสดง preview และปุ่ม override `ตรง`, `โค้งวงกลม`, `โค้งอิสระ`
- `DESIGN` เก็บทั้ง raw samples และ fitted entity เพื่อแก้ fit ภายหลังได้

### Snapping

- `PUBLIC` endpoint, midpoint, arc center, profile center และ grid snap
- `PUBLIC` sketch guide lines และข้อความบอกชนิด snap
- `DESIGN` snap เข้าขอบภาพเฉพาะใน corridor รอบเจตนาของผู้ใช้
- `DESIGN` snap จุดปลายเข้าจุดเริ่มเมื่ออยู่ใน tolerance เพื่อปิดรูป
- `DESIGN` snap ต้องมี hysteresis ป้องกันจุดกระโดดไปมาระหว่างขอบใกล้กัน
- `DESIGN` แสดง source ของ snap: `LiDAR plane`, `visual edge`, `existing endpoint`, `manual`

### Constraints

- `PUBLIC` Coincident
- `PUBLIC` Tangent
- `PUBLIC` Horizontal/Vertical
- `PUBLIC` Parallel/Perpendicular
- `PUBLIC` Concentric/Equal
- `PUBLIC` Lock และ dimensions
- `DESIGN` รุ่นแรกใช้ Coincident และ Tangent อัตโนมัติ ส่วน constraints อื่นเป็นคำแนะนำเท่านั้น
- `DESIGN` ห้าม constraint solver เปลี่ยนจุดวัดเกิน uncertainty ของข้อมูลจริง

### Editing

- `PUBLIC` เลือก entity แล้วปรับจุดหรือ dimension
- `PUBLIC` แยกสถานะ fully defined และ under-defined ด้วยสี
- `DESIGN` แตะด้านเพื่อเลือก จากนั้นลาก endpoint, midpoint, arc handle หรือ spline control point
- `DESIGN` magnifier แสดงภาพขยายบริเวณจุดที่กำลังแก้
- `DESIGN` มี `Undo`, `Redo`, `Delete side`, `Refit`, `Restore raw`

## 3. SOLIDWORKS Sketch and Validation Pattern

ต้นทาง: [Automatic Sketch Operations](https://help.solidworks.com/2022/english/SolidWorks/acadhelp/c_Automatic_Sketch_Operations_AcadHelp.htm), [Sketch Relations](https://help.solidworks.com/2024/English/SolidWorks/Sldworks/c_Description_of_Sketch_Relations.htm), [Spline Tools](https://help.solidworks.com/2026/english/SolidWorks/sldworks/r_Spline_Tools_Toolbar.htm), [Fit Spline](https://help.solidworks.com/2024/English/SolidWorks/Sldworks/c_Fit_Splines.htm), [Repair Sketch](https://help.solidworks.com/2022/english/SolidWorks/sldworks/HIDD_SKETCH_GEOM_DIAGNOSTICS_impexp.htm), [Check Sketch](https://help.solidworks.com/2021/english/SolidWorks/sldworks/c_error_message_check_sketch.htm), [Shaded Sketch Contours](https://help.solidworks.com/2023/english/Solidworks/sldworks/c_Shaded_Sketch_Contour.htm), [Section Properties](https://help.solidworks.com/2026/english/SolidWorks/sldworks/c_section_properties.htm)

### Sketch construction

- `PUBLIC` เปลี่ยนต่อเนื่องระหว่าง line และ tangent arc
- `PUBLIC` automatic relations และ inferencing
- `PUBLIC` Fit Spline รวมหลาย segment เป็น spline เดียวและคง parametric link
- `PUBLIC` spline tools: tangency, curvature, control points, simplify, inflection points, minimum radius และ curvature comb
- `PUBLIC` geometry status: under-defined, fully-defined, over-defined, conflicting, unsolvable และ invalid
- `DESIGN` ใช้สถานะของเราเป็น `Draft`, `Measured`, `Fitted`, `Confirmed`, `Low confidence`, `Invalid`

### Profile validation

- `PUBLIC` ตรวจ open/closed contours
- `PUBLIC` ตรวจ endpoint ที่เชื่อมกับหลาย entity ผิดปกติ
- `PUBLIC` ตรวจเส้นสั้นมาก ช่องว่าง overlap และเส้น/arc ซ้อนกัน
- `PUBLIC` spline self-intersection เป็น invalid geometry
- `PUBLIC` shaded contour ทำให้เห็นทันทีว่าพื้นที่ปิดสมบูรณ์หรือไม่
- `DESIGN` ระบายสีพื้นที่เฉพาะเมื่อ loop ปิดและ topology ผ่าน
- `DESIGN` highlight จุดผิดพร้อม magnifier และคำสั่งแก้ทีละจุด
- `DESIGN` auto-repair ทำได้เฉพาะช่องว่างหรือ overlap ที่เล็กกว่าค่าความไม่แน่นอน
- `DESIGN` ห้ามปิด gap ใหญ่โดยอัตโนมัติ ต้องให้ผู้ใช้ยืนยันเส้นปิด

### Curve quality

- `PUBLIC` แสดง inflection points, minimum radius และ curvature comb
- `PUBLIC` Simplify Spline ลดความซับซ้อนของ spline
- `DESIGN` แสดง warning เมื่อ spline oscillates, มี control point มากเกิน หรือโค้งย้อนผิดธรรมชาติ
- `DESIGN` adaptive fitting ต้องรักษามุมคมและ tangent continuity ที่ผู้ใช้ยืนยัน

### Area and properties

- `PUBLIC` open geometry ไม่มี area
- `PUBLIC` section properties รองรับ planar sketches/faces และคำนวณ area-based properties
- `DESIGN` คำนวณ signed area จากแต่ละ parametric segment ด้วย Green's theorem
- `DESIGN` เส้นตรงและ circular arc ใช้สูตร analytic
- `DESIGN` Bézier/B-spline ใช้ adaptive numerical integration พร้อม error bound
- `DESIGN` รายงาน area, perimeter, centroid, per-side length และ uncertainty
- `DESIGN` ตรวจผลซ้ำด้วย tessellated shoelace calculation เพื่อจับ numerical bug

## 4. magicplan Pattern

ต้นทาง: [Manual Scan](https://help.magicplan.app/scan-a-room-in-seconds-using-lidar), [LiDAR Auto-Scan](https://help.magicplan.app/auto-scan-your-floor-plan), [Accuracy guidance](https://help.magicplan.app/how-accurate-is-magicplan)

### เก็บมาใช้

- `PUBLIC` แยก manual/corner mode กับ automatic detection mode และสลับได้กลางงาน
- `PUBLIC` grid ช่วยเล็งผ่านสิ่งกีดขวาง
- `PUBLIC` indicator สีเขียวบอกตำแหน่งจุดถัดไป
- `PUBLIC` ส่วนที่เก็บสำเร็จเปลี่ยนเป็นสีเขียวและมีเครื่องหมายยืนยัน
- `PUBLIC` ส่วนที่ไม่สมบูรณ์ใช้สีส้มและให้เลือกยืนยันหรือสแกนใหม่
- `PUBLIC` review ก่อน generate ผลลัพธ์
- `PUBLIC` ถ้าตรวจอัตโนมัติไม่ได้ ให้กำหนดกรอบหรือจุดด้วยมือ
- `DESIGN` โหมดของเรา: `Auto Assist`, `Point`, `Line`, `Arc`, `Free Curve`
- `DESIGN` ต้องกลับไป manual ได้ทันทีโดยไม่สูญเสียด้านที่ยืนยันแล้ว

### ไม่เก็บมาใช้ตรง ๆ

- `OUT` RoomPlan object recognition เช่นเฟอร์นิเจอร์ ประตู หน้าต่าง
- `OUT` การเดาปิดห้องอัตโนมัติเมื่อขอบจริงไม่ถูกมองเห็น

## 5. Polycam and Canvas Capture Pattern

ต้นทาง: [Polycam As-Built Capture](https://learn.poly.cam/hc/en-us/articles/48338504343188-How-to-Capture-As-Built-Drawings), [Polycam capture modes](https://learn.poly.cam/hc/en-us/articles/48565771018772-Which-Capture-Mode-Should-I-Use), [Polycam Object Mode](https://learn.poly.cam/hc/en-us/articles/27425185907348-How-to-Use-Object-Mode), [Polycam mechanical parts](https://learn.poly.cam/hc/en-us/articles/48336423303572-How-to-3D-Scan-Mechanical-Parts), [Twindo scanning overview](https://www.twindo.com/support/tutorial-how-to-scan-a-room-with-canvas/)

### เก็บมาใช้

- `PUBLIC` guided capture แสดง point-cloud/coverage สดเพื่อเห็นบริเวณที่ขาด
- `PUBLIC` พื้นที่ที่ยังต้องเก็บถูก highlight
- `PUBLIC` แนะนำให้เคลื่อนช้า รักษาระยะ และกลับมาซ้อนทับจุดเริ่มต้น
- `PUBLIC` เตือนพื้นผิวสะท้อน แสงไม่สม่ำเสมอ และวัตถุไร้ texture
- `PUBLIC` haptic feedback เมื่อเก็บ sample สำเร็จ
- `PUBLIC` review, rescale, measurement และ export หลัง capture
- `DESIGN` แผนที่คุณภาพบนระนาบแบ่งเป็น cells ไม่ใช่ mesh ทั้งวัตถุ
- `DESIGN` cell แสดงสถานะ `unseen`, `low depth confidence`, `good`, `edge observed`
- `DESIGN` เส้นขอบแสดงช่วงที่มี RGB/depth evidence และช่วงที่มาจากการ fit

### ไม่เก็บมาใช้ตรง ๆ

- `OUT` photogrammetry 360 องศาและ full object mesh
- `OUT` cloud processing เป็นข้อบังคับ
- `OUT` เติมพื้นที่ที่มองไม่เห็นโดยไม่แจ้งผู้ใช้

## 6. Leica DISTO Plan Pattern

ต้นทาง: [Leica learning centre](https://leica-geosystems.com/en-gb/products/disto-and-leica-lino/learning-centre-for-disto-and-leica-lino), [Measure Plan overview](https://leica-geosystems.com/-/media/files/leicageosystems/disto%20and%20leica%20lino/disto_tutorial_03_measure-plan_plan-app_2024-02_geo-bld-lgs-en-en.pdf)

### เก็บมาใช้

- `PUBLIC` เลือกชนิดข้อมูลเป็น Point, Line หรือ Area ก่อนวัด
- `PUBLIC` วัดรูปทรงใหญ่และผิดรูปด้วยลำดับจุด
- `PUBLIC` snap ใกล้จุดที่มีอยู่
- `PUBLIC` sketch ที่วาดคร่าว ๆ รับค่าระยะจริงภายหลังได้
- `PUBLIC` export 2D/CAD และเก็บรายการค่าที่วัด
- `DESIGN` แยก `observed geometry` ออกจาก `confirmed dimensions`
- `DESIGN` ให้ผู้ใช้ใส่ค่าความยาวอ้างอิงจากตลับเมตรเพื่อ calibration/verification ได้

### ไม่เก็บมาใช้ตรง ๆ

- `OUT` การบังคับใช้อุปกรณ์ laser ภายนอก
- `OUT` workflow บนขาตั้งที่ไม่เหมาะกับผู้ใช้ถือ iPhone

## 7. Apple Framework Capabilities

ต้นทาง: [ARKit scene depth](https://developer.apple.com/documentation/arkit/arframe/scenedepth), [ARKit Environmental Analysis](https://developer.apple.com/documentation/arkit/environmental-analysis), [Vision contour detection](https://developer.apple.com/documentation/vision/detectcontoursrequest), [RoomPlan](https://developer.apple.com/documentation/roomplan)

### Sensor and tracking

- `PUBLIC` Scene depth ให้ระยะจากกล้องสู่พื้นที่ในภาพพร้อม confidence
- `PUBLIC` Smoothed scene depth ลดความผันผวนระหว่างเฟรม
- `PUBLIC` AR raycast หา 3D position บนพื้นผิวจริงจากจุดบนหน้าจอ
- `DESIGN` fit ระนาบจาก depth samples หลายเฟรมด้วย robust estimator
- `DESIGN` freeze plane coordinate frame หลังผู้ใช้ยืนยัน และติดตาม drift แยกต่างหาก
- `DESIGN` ไม่ใช้ LiDAR sample เดี่ยวเป็น endpoint สุดท้าย

### Visual assistance

- `PUBLIC` Vision ตรวจ image contours ได้
- `DESIGN` จำกัด contour search ให้อยู่ใกล้เส้น intent ของผู้ใช้
- `DESIGN` fusion score รวม image gradient, depth continuity, temporal stability และ geometry residual
- `DESIGN` เมื่อขอบสีเดียวกันหรือ contrast ต่ำ ให้ลดความมั่นใจและกลับ manual control points

### Coaching

- `PUBLIC` RoomPlan มี real-time overlays และคำแนะนำให้ขยับอุปกรณ์
- `PUBLIC` คำแนะนำรวม move closer, move away, slow down, turn on light และ low texture
- `DESIGN` เพิ่มคำแนะนำเฉพาะงาน: `หันกล้องให้ตั้งฉากขึ้น`, `ขอบหลุดจากภาพ`, `กลับมาเก็บช่วงสีส้ม`, `ถือให้นิ่ง`

## 7.1 QCAD Public-Source Geometry Findings

ต้นทาง: official QCAD artifact inventory และ public source revision `f0b35cb4ff79613693bdc0c0bcbf723f445f71ac`; รายละเอียดอยู่ใน `research/rea/qcad/3.33.1/`

- `OBSERVED` แยก logical closure ออกจาก geometric closure ที่ยอมรับได้ภายใน tolerance
- `DESIGN` สถานะ profile ของเราเป็น `open` → `near start` → `closed`; ห้ามแปลงเป็น closed จนผู้ใช้ยืนยัน
- `OBSERVED` ความยาว polyline นับ last-to-first segment เฉพาะเมื่อปิดเชิงตรรกะแล้ว
- `DESIGN` แสดง closing segment และความยาวก่อนผู้ใช้กด `ปิดพื้นที่`
- `OBSERVED` sector area และ circular-segment area เป็นคนละปริมาณ และ arc segment รองรับสูตร exact `r²(θ − sin θ)/2`
- `DESIGN` ใช้ exact line/arc Green integral และใช้ adaptive integration เฉพาะ spline
- `OBSERVED` การ snap ใน 3D view ใช้ระยะใน view coordinates ส่วน 2D ใช้ model-space distance
- `DESIGN` แยก screen-space capture radius เพื่อใช้ง่าย ออกจาก metric closure tolerance เพื่อไม่บิดผลวัด
- `DESIGN` ห้ามคัดลอก implementation จาก QCAD เพราะ public source เป็น GPL; ใช้เป็นข้อกำหนดและ test oracle เท่านั้น

## 8. Unified Product Workflow

1. `Prepare` ตรวจกล้อง LiDAR แสง ระยะ และ tracking
2. `Find Plane` ผู้ใช้เล็งกลางแผ่น ระบบแสดง grid และ plane confidence
3. `Lock Plane` ผู้ใช้ยืนยันระนาบและ orientation
4. `Place Start` เป้ากลางจอเลือกจุดเริ่ม
5. `Capture Side` ระบบเก็บ samples และแสดง preview geometry
6. `End Side` ผู้ใช้ยืนยัน endpoint และชนิด geometry
7. `Repeat` endpoint เดิมเป็น start point ใหม่
8. `Close Profile` snap เข้าจุดแรกหรือสร้าง closing segment หลังยืนยัน
9. `Validate` ตรวจ gap, overlap, self-intersection, short entity และ low-confidence spans
10. `Review` แก้ด้านและดู shaded closed profile
11. `Calculate` area, perimeter, centroid, per-side lengths และ uncertainty
12. `Verify` ให้ผู้ใช้เทียบระยะอ้างอิงหนึ่งเส้นถ้าต้องการความมั่นใจสูง
13. `Save/Export` เก็บภาพ หลักฐานคุณภาพ geometry และผลคำนวณ

## 9. Required Product Functions

### Capture

- Camera permission and LiDAR capability checks
- Plane discovery, plane lock and relock
- Center reticle and offset magnifier
- Tap-to-place and optional hold-to-sample
- Per-frame tracking/depth confidence
- Coverage and evidence overlay
- Flashlight and exposure assistance
- Haptic and audio confirmations

### Geometry

- Line, arc, Bézier/B-spline and explicit closing segment
- Model fitting with residual and uncertainty
- Endpoint, edge and tangent snapping
- Raw-sample retention
- Segment type override
- Per-segment edit handles and dimensions
- Undo/redo transaction history

### Validation

- Closed-loop test
- Gap/overlap detection
- Duplicate/near-zero segment detection
- Self-intersection detection
- Multiple-loop/hole detection
- Off-plane sample rejection
- Drift and relocalization detection
- Low-confidence span detection
- Repair suggestions with user confirmation

### Calculation

- Analytic line/arc lengths
- Adaptive spline arc length
- Signed Green-theorem area by segment
- Tessellated shoelace cross-check
- Perimeter and centroid
- Unit conversion
- Error/uncertainty estimate
- Repeat-measurement comparison

### Review and export

- Filled profile preview
- Side list with type, length and confidence
- Original camera snapshot with overlay
- JSON project with raw and fitted data
- CSV measurement summary
- PDF/image report
- Future DXF/SVG export

## 10. REA Coverage and Remaining Questions

- `OBSERVED` Apple Measure 175.100.3.0.1, magicplan 2026.41.0, Polycam 7.0.6 และ DISTO Plan 3.3.0 เปิดสำเร็จบน iPhone 16 Pro ใน controlled launch; หลักฐานนี้ยืนยันเฉพาะ lifecycle
- `OBSERVED` Twindo 1.0.90 รับ launch request แต่ process ไม่คงอยู่ และไม่พบ crash log ที่ตรงเป้าหมายในการค้นหาแบบจำกัด
- `REA-BLOCKED` Frida attach ถูกบล็อกเพราะ iOS เป็น stock/jailed และต้องมี Gadget; control test กับ SurfaceMeasure ของเราให้สาเหตุเดียวกัน
- `REA-BLOCKED` Exact timing, state transitions and haptic behavior of Apple Measure
- `REA-PENDING` Exact thresholds and gesture transitions in Shapr3D Automatic Line/Arc
- `REA-PENDING` Exact repair sequencing and error presentation in SOLIDWORKS sketches
- `REA-BLOCKED` Exact coverage visualization and capture-state transitions in Polycam/Twindo
- `REA-BLOCKED` Exact snap behavior and area workflow in DISTO Plan
- `REA-BLOCKED` Exact manual/automatic mode switching behavior in magicplan
- `REA-PENDING` Exact SketchUp inference priority, visual cues and face-closure transition; official artifact downloaded but REA intake is blocked until the retained Hopper session is reset

การตรวจ iOS ให้ลึกกว่านี้ต้องใช้ build ที่เราเป็นเจ้าของและใส่ observability/Gadget แบบ debug-only หรือ artifact ที่ได้รับอนุญาตและไม่ติด DRM เท่านั้น การเพิ่ม Gadget โดย repackage/re-sign แอป App Store อยู่นอกขอบเขตนี้ ห้ามนำ proprietary code, assets, strings หรือ private protocols มาใส่ในผลิตภัณฑ์
