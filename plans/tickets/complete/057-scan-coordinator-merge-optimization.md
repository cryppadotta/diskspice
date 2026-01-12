# 057: Optimize ScanCoordinator Merge Path to Avoid O(n^2) Updates

## Dependencies
- 027 (Scanner UI integration)

## Task
Reduce per-update cost when merging scanned nodes by replacing linear searches with a dictionary-based merge keyed by path.

## Spec Reference
SPEC.md > Scanning Engine (progressive updates) and Core Principles > Speed.

## Implementation Details
- In `ScanCoordinator.handleNodeUpdate` and `flushPendingUpdates`, avoid repeated `firstIndex(where:)` scans.
- Convert `pendingUpdates` to store a dictionary keyed by `URL` (or `String` path) for O(1) merges.
- When flushing, merge into existing children using a dictionary keyed by `path`, then rebuild the array.
- Preserve ordering as much as possible: keep existing order and append truly new nodes at the end.
- Ensure behavior is identical: nodes are updated, added, and `appState.updateChildren` is called once per path per flush.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/ScanCoordinator.swift` - replace array-based merge with dictionary-based merge.

## Acceptance Criteria
- [ ] Merge time is O(n) per flush instead of O(n^2) for large folders.
- [ ] No change in visible behavior (nodes update and appear as before).
- [ ] `pendingUpdates` is cleared after flush.

## Completion Promise
`<promise>TICKET_057_COMPLETE</promise>`
