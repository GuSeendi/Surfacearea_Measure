# Runtime Scenarios

## Scenario A — Controlled launch request

- Date: 2026-10-21 (Asia/Bangkok)
- Action: launch `com.twindo.mobile` through CoreDevice under REA process capture
- Result: launch request succeeded; exit code 0; cleanup verified
- Evidence: `ev_a060f205a96fc997fd67411cf7c08abf0b20bb2609ae45bdae0be59c84080373`

## Scenario B — Process retention and crash-log check

- Action: repeat target-only process check immediately after launch; search target-named system crash logs
- Result: process not retained; no matching crash log found
- Interpretation: startup outcome unknown; do not label this a crash without stronger evidence
