# 2D Shadow-Area Validation Protocol

The app must not claim certified accuracy until this protocol has been completed on the target iPhone and the supported workpiece classes.

## Traceable reference silhouettes

Use dimensionally stable targets whose orthographic area is independently known:

1. 200 × 300 mm rectangle — 0.060000 m².
2. 500 × 800 mm rectangle — 0.400000 m².
3. 250 mm diameter circle — area calculated from a calibrated diameter.
4. Mixed profile containing straight sides and known-radius circular arcs.
5. Concave non-self-intersecting polygon.
6. The same silhouettes placed at several depths while retaining the same orthographic projection.

Record reference instrument, calibration date, dimensions, temperature and reference uncertainty.

## Conditions

- Distances: 0.4, 0.7, 1.0, 1.5, 2.0 and 3.0 m where the target remains resolvable.
- View angles: frontal, 20°, 40° and the validated maximum obliquity.
- Lighting: indoor diffuse, outdoor shade and bright indirect light.
- Surfaces: matte light, matte dark, low-texture and moderately reflective.
- Motion paths: stationary reach, lateral walk, forward/backward walk and return-to-start loop.
- Device thermal states: nominal and fair.

Reflective, transparent, wet or moving boundaries must be rejected unless separately validated.

## Repeatability

- At least three operators.
- Ten independent measurements per target/condition/operator.
- Reset AR tracking between runs.
- Include rejected attempts in the failure-rate analysis.
- Trace half the runs clockwise and half counter-clockwise.
- Repeat a subset on different days.

## Record for every run

- Reference area and uncertainty.
- Reported area and estimated uncertainty.
- Absolute and relative error.
- Perimeter and every segment length.
- Trace direction and selected line/arc mode.
- Mean and maximum fit residual.
- Depth-confidence distribution.
- Camera distance, speed and frontal-angle distribution.
- Closure gap before snapping.
- Tracking interruptions or relocalization events.
- Duration, retries, device/iOS version, thermal state and lighting/material notes.

## Provisional engineering acceptance

- Mean absolute percentage error ≤ 2% within the validated envelope.
- 95th-percentile absolute percentage error ≤ 3%.
- Within-operator repeatability standard deviation ≤ 1%.
- No accepted result with an open, crossing or overlapping profile.
- False-accept rate below 1% for deliberately poor depth, excessive speed, oblique viewing and relocalization tests.
- Clockwise/reverse mean-area difference ≤ 1.5%.
- At least 95% of accepted reference values fall inside the app's reported uncertainty interval.

These are initial release gates, not current performance claims.

## Failure challenges

- Walk closer and farther while tracing the same edge.
- Temporarily cover the camera/LiDAR.
- Leave the app and return during a trace.
- Force a large closure gap.
- Draw a bow-tie crossing and a backtracking overlapping edge.
- Trace a straight edge in arc mode and a curved edge in line mode.
- Use an object with changing physical depth but an unchanged 2D projection.
- Heat the device to serious thermal state and verify capture pauses.

## Release statement

Published accuracy must identify the validated iPhone model, iOS version, target-size range, distance range, maximum angle, supported materials, lighting, operator method and confidence level. Until then, exports must retain: `สถานะการสอบเทียบ: ยังไม่ผ่านการรับรองแบบ traceable`.
