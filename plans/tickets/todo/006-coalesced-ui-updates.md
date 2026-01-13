# 006: Coalesce Scan Updates for UI Smoothness

## Dependencies
- 002

## Task
Batch and coalesce frequent scan updates so the UI stays responsive during partial scans.

## Spec Reference
SPEC.md > Core Principles (Speed)

## Implementation Details
- Add a coalescing layer for updates that arrive in rapid succession.
- Ensure list updates occur at a fixed interval (e.g., 100–200ms) during heavy scans.
- Keep selection state stable during update batches.

## Files to Create/Modify
- `DiskSpice/DiskSpice/App/AppState.swift` - Coalesced updates for fileTree changes.
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - Throttle directory updates if needed.

## Acceptance Criteria
- [ ] UI updates are coalesced during heavy scans.
- [ ] Selection remains intact during batched updates.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_006_COMPLETE</promise>`
