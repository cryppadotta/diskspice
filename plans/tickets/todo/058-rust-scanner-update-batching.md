# 058: Batch Rust Scanner Messages to Reduce Main-Thread Churn

## Dependencies
- 007 (Rust scanner implementation)
- 027 (Scanner UI integration)

## Task
Reduce main-thread overhead by batching Rust scanner messages before updating `AppState`.

## Spec Reference
SPEC.md > Scanning Engine (progressive updates) and Core Principles > Speed.

## Implementation Details
- In `RustScanner`, buffer decoded `RustScanMessage.entry` items in memory.
- Flush buffered entries to the delegate on a timer (e.g., every 50-100ms) or when a folder completes.
- Keep error and completion messages immediate.
- Ensure batching works with existing debounce logic in `ScanCoordinator` (avoid double-batching delays longer than ~100ms).
- Make sure `scannerDidComplete` still fires when the process exits.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/RustScanner.swift` - add entry buffering and timed flush to delegate callbacks.

## Acceptance Criteria
- [ ] UI updates during Rust scans are visibly smoother for directories with many files.
- [ ] Entry updates are delivered in batches without losing data.
- [ ] Error and completion messages are not delayed.

## Completion Promise
`<promise>TICKET_058_COMPLETE</promise>`
