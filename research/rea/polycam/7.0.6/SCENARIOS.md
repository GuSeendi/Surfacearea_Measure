# Runtime Scenarios

## Scenario A — Controlled launch

- Date: 2026-10-21 (Asia/Bangkok)
- Action: launch `ai.polycam.polycam` through CoreDevice under REA process capture
- Result: launch succeeded; exit code 0; cleanup verified
- Evidence: `ev_9cb08bdc37c24d2c15618013e6a4032495cd5a7e03377cdff40a17a586725b11`
- Coverage: lifecycle only

## Scenario B — Bounded attach probe

- Intended scope: enumerate only loaded modules relevant to AR/camera/depth/vision; no file, account, project or network access
- Result: `capability_unavailable`; no session opened
- Interpretation: instrumentation blocked by the stock-iOS Gadget requirement, not evidence that a module is absent
