# 002: Add Budgeted Directory Scanning

## Dependencies
- 001

## Task
Implement a time/entry budget per directory scan so large folders return partial results quickly and resume later.

## Spec Reference
SPEC.md > Scanning Engine; SPEC.md > Core Principles (Speed)

## Implementation Details
- Add a per-directory time budget (ms) and item limit to SwiftScanner.
- When budget is hit, return partial children and flag the directory for rescan.
- Re-enqueue partial directories in ScanQueue with high priority until completed.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/SwiftScanner.swift` - Budgeted scanning with partial return metadata.
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - Rescan incomplete directories until done.
- `DiskSpice/DiskSpice/App/AppState.swift` - Keep partial sizes visible during rescan.

## Acceptance Criteria
- [ ] Large directories return partial results within the budget.
- [ ] Partial directories are re-queued and eventually complete.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_002_COMPLETE</promise>`
