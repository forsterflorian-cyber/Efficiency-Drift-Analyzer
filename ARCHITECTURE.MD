# EDA Architecture

## Purpose

EDA (Efficiency Drift Analyzer) is a real-time Garmin data field for aerobic decoupling analysis.

Its main purpose is to:

- ingest live workout sensor data
- validate whether current data is usable
- resolve the active workload model
- accumulate drift over time
- communicate confidence/status to the user
- export only trustworthy FIT values

The system must stay:

- deterministic
- lightweight
- robust against lifecycle interruptions
- clear in user-facing status output

---

# High-Level Flow

Sensors / Activity Info  
↓  
Raw Sample Capture  
↓  
Freshness + Validity Checks  
↓  
Profile / Workload Resolution  
↓  
Source Selection (Power vs Pace/Speed)  
↓  
Drift Accumulation Engine  
↓  
Status Derivation  
↓  
Render Model / Display  
↓  
FIT Export Gating / Session Summary

---

# Main Modules

## 1. EDAView

Primary orchestration layer.

Main responsibilities:

- receive live activity/sensor data
- react to lifecycle events
- coordinate validation and state transitions
- invoke profile resolution
- invoke source selection
- feed the drift engine
- prepare render state
- gate FIT export behavior

Important note:

`EDAView.compute()` is the main integration hotspot and highest-risk area for regressions.

---

## 2. EDAProfileResolver

Profile/type resolution layer.

Responsibilities:

- determine whether activity context is known enough
- classify type certainty
- move between unresolved / provisional / authoritative / fallback / stale states
- support workload eligibility decisions

Why it matters:

This module influences whether speed fallback is allowed, whether source selection is trustworthy, and whether the visible status should communicate confidence or uncertainty.

---

## 3. EDADriftEngine

Hot-path calculation layer.

Responsibilities:

- accumulate workload and heart-rate efficiency data
- maintain bucketed / rolling decoupling state
- react safely to data gaps
- preserve predictable runtime cost

Constraints:

- must remain efficient
- should avoid unnecessary allocations
- should not be burdened with UI or lifecycle concerns

---

## 4. EDAFitExportState

Export and persistence policy layer.

Responsibilities:

- manage whether values are fit for FIT export
- manage session summary behavior
- reset summary/export state when validity conditions require it

Important:

Export must be more conservative than display.  
Display may show provisional states; FIT export should only persist trustworthy results.

---

## 5. EDARenderer

Rendering layer.

Responsibilities:

- assemble final numeric values for display
- construct user-visible status text
- ensure UI clarity

Important rule:

User-facing text must reflect the internal state truthfully.

Avoid situations where:

- UI suggests sensor failure when the real issue is profile resolution
- UI shows a confident value when underlying data is provisional

---

# Lifecycle Model

EDA depends on Garmin timer lifecycle events.

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
- protected with hysteresis
- resilient to noisy sensors

Avoid:

- rapid source thrashing
- unnecessary full analysis resets
- switching based on transient noise

---

# Status Model

User-visible statuses include:

- Provisional
- Retry
- Valid

These represent **confidence in data quality**, not simply data presence.

UI must never claim more certainty than the system actually has.

---

# Data Freshness Model

EDA conceptually operates on three layers of data:

Raw Live Sample  
→ newest sensor value

Validated Sample  
→ sample that passed freshness + validity checks

Display Sample  
→ safe value to show to the user

This separation prevents stale or invalid samples from leaking into UI or drift analysis.

---

# Runtime Constraints

EDA runs in the Garmin Connect IQ runtime.

Constraints include:

- limited memory
- limited CPU
- frequent update cycles

Therefore:

- hot paths must stay lightweight
- avoid allocations in compute loops
- avoid repeated string construction
- keep logic deterministic

---

# Known Fragile Areas

Historically fragile areas include:

- lifecycle handling across pause/resume
- source switching under noisy sensors
- stale sensor values surviving state transitions
- UI/status drifting from internal truth
- status composition built from multiple flags

These areas require special care during stabilization.

---

# Change Philosophy

When modifying this repository, prioritize:

1. stability
2. determinism
3. user trust in displayed status
4. runtime efficiency

Preferred changes:

- small targeted fixes
- explicit logic
- minimal diffs

Avoid:

- broad architectural rewrites
- speculative optimizations
- feature expansion during stabilization passes