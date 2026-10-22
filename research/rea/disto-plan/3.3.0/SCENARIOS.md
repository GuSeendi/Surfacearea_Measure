# Runtime Scenarios

## Scenario A — Controlled launch

- Date: 2026-10-21 (Asia/Bangkok)
- Action: launch `com.leica-geosystems.disto-plan` through CoreDevice under REA process capture
- Result: launch succeeded; exit code 0; cleanup verified
- Evidence: `ev_627dc6a78795cad542d9b2788b1877d58c77a5ed677e775087ab662a7d926b1d`
- Coverage: lifecycle only

## Scenario B — Bounded attach probe

- Intended scope: enumerate only loaded modules relevant to AR/camera/depth/vision; no pairing, file, project or network access
- Result: `capability_unavailable`; no session opened
- Interpretation: instrumentation blocked by the stock-iOS Gadget requirement, not evidence that a module is absent
