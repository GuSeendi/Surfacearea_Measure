# Limitations

- No Apple Measure IPA or executable was extracted from the device.
- No signing, entitlement or platform-security bypass was attempted.
- The controlled replay proves only that the selected bundle launched successfully.
- REA could not attach Frida because the stock/jailed iOS path requires Frida Gadget. The same blocker was reproduced against the developer-owned SurfaceMeasure control app.
- No attempt was made to modify, repackage or re-sign Apple Measure.
- No UI automation, screen recording, camera capture, existing measurement access, network capture or filesystem inspection was performed.
- Process sampling can omit short-lived descendants, and the host environment inherited by `xcrun` was not recorded.
