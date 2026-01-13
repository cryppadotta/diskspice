# 001: Implement Two-Phase Directory Sizing

## Dependencies
- None

## Task
Add a two-phase sizing pass so directories appear quickly with an initial estimate, then refine to final size once deeper scanning completes.

## Spec Reference
SPEC.md > Scanning Engine; SPEC.md > Core Principles (Speed)

## Implementation Details
- Update Swift scanner/queue to mark directory entries as partial on first pass and then replace with final size.
- Keep UI responsive by emitting early results even if deeper scans are pending.
- Ensure repeated updates for the same path merge cleanly in AppState.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/SwiftScanner.swift` - Emit initial estimates for directories.
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - Treat initial estimates as partial and allow refinement.
- `DiskSpice/DiskSpice/App/AppState.swift` - Merge partial updates without clobbering full results.

## Acceptance Criteria
- [ ] Directories show a size estimate quickly before full scan completes.
- [ ] Final size replaces the estimate after deeper scans finish.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_001_COMPLETE</promise>`
