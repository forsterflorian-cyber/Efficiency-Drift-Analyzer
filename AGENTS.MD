# EDA – Agent Guidance

This repository contains **Efficiency Drift Analyzer (EDA)**, a real-time aerobic decoupling analysis data field for Garmin devices.

The system runs inside the Garmin Connect IQ runtime (Monkey C) and must remain **predictable, lightweight, and robust under real-time constraints**.

Agents modifying this repository must follow the rules below.

---

# Core Architecture

Main execution path:

EDAView.compute()

This function orchestrates:

- sensor ingestion
- lifecycle repair (pause/resume)
- profile resolution
- source selection (pace vs power)
- drift accumulation
- render model update
- FIT export decisions

Supporting modules:

EDAProfileResolver  
→ resolves activity type and workload source  
→ states: unresolved / provisional / authoritative / fallback

EDADriftEngine  
→ O(1) drift accumulation logic  
→ hot-path runtime component

EDAFitExportState  
→ FIT export behavior and session summary resets

EDARenderer  
→ final UI text and numeric rendering

---

# Runtime Constraints

This is a **real-time Garmin data field**.

Key constraints:

- compute() runs every update cycle
- memory is limited
- allocations in hot paths should be avoided
- runtime cost must remain stable

Agents must not introduce:

- large allocations in compute()
- expensive loops in hot paths
- repeated string creation during update cycles

---

# Lifecycle Model

The app depends on Garmin timer lifecycle events.

Relevant transitions:

- start
- pause
- resume
- lap
- stop

Important rules:

1. State must remain consistent across pause/resume.
2. Pre-pause sensor values must not appear as fresh data after resume.
3. Lifecycle recovery must not silently reset analysis unless necessary.

---

# Workload Source Model

EDA can derive workload from:

- Power
- Speed/Pace

Source selection must be:

- deterministic
- hysteresis-protected
- resilient to noisy sensors

Agents must avoid introducing **source thrashing**.

---

# Status Model

User-visible statuses include:

- Provisional
- Retry
- Valid

These statuses communicate **data confidence**, not just data presence.

Agents must ensure that UI status always reflects the true internal state.

Avoid situations where:

- UI shows Valid while data is provisional
- UI indicates sensor failure when the issue is profile resolution

---

# UI Rendering

User-visible text is assembled across:

- EDARenderer
- EDAView helpers
- resources/strings

Agents should prefer:

- structured status composition
- minimal runtime string concatenation

---

# FIT Export

FIT export behavior must remain conservative.

Export must only occur when:

- drift values are valid
- data integrity is guaranteed
- fallback states are resolved

---

# Testing

Current automated tests are limited.

When modifying:

- lifecycle handling
- source switching
- status generation

agents should add targeted tests if feasible.

---

# Change Philosophy

This project prioritizes:

1. stability
2. determinism
3. clarity of user feedback
4. runtime efficiency

Agents should prefer:

- small targeted fixes
- minimal diffs
- explicit logic

Agents must avoid:

- architectural rewrites
- feature additions unless explicitly requested
- speculative optimizations

---

# Typical Failure Modes

Common issues in Garmin real-time apps include:

- stale sensor values surviving pause/resume
- source switching oscillation
- status/UI desynchronization
- drift calculations running on invalid windows

Agents should actively look for these issues during stabilization passes.