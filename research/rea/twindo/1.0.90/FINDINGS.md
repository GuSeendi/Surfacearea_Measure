# Findings

## Observations

- CoreDevice identified Twindo 1.0.90 build 258 with bundle identifier `com.twindo.mobile` on the paired iPhone 16 Pro.
- REA's bounded launch request succeeded and cleanup was verified. Evidence: `ev_a060f205a96fc997fd67411cf7c08abf0b20bb2609ae45bdae0be59c84080373`.
- The Twindo process was not present immediately after launch in repeated target-only process checks.
- A bounded target-name search of available system crash logs found no matching Twindo/Canvas entry. This does not prove that no failure occurred.

## Public functional evidence

- Twindo recommends beginning at a textured/detail-rich corner, maintaining roughly 5–10 ft distance, moving slowly in a repeated up/down “fence painting” path, continuing in one direction around the perimeter, and returning to the starting point.
- It warns against pivoting without continuing the capture pattern, changing floors during one scan, and capturing the same area more than once.

## Clean-room implications

- SurfaceMeasure should coach a controlled path and stable standoff distance while allowing the user to walk, rather than assume a fixed camera position.
- Duplicate samples and relocalization after movement must be detected rather than averaged blindly.

## Unknowns

- Whether the process exit is expected startup behavior, configuration/account gating, compatibility, or an unlogged failure.
- Internal frameworks, state transitions and algorithms were not observed.
