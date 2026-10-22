# Runtime Scenarios

## Scenario A — Controlled launch

- Date: 2026-10-21 (Asia/Bangkok)
- Action: launch `com.sensopia.magicplan` through CoreDevice under REA process capture
- Result: launch succeeded; exit code 0; cleanup verified
- Evidence: `ev_0e522d95912b007fdc955bf77d5aac875fd48c21a2f7e1f5f2b4ca15a6cc90c5`
- Coverage: lifecycle only

## Scenario B — Bounded attach probe

- Intended scope: enumerate only loaded modules relevant to AR/camera/depth/vision; no file, account, project or network access
- Result: `capability_unavailable`; no session opened
- Interpretation: instrumentation blocked by the stock-iOS Gadget requirement, not evidence that a module is absent
