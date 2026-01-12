# 035: Add Last-Scanned Timestamps

## Dependencies
- 032 (cache data structure)

## Task
Store and display last-scanned timestamp per folder for user awareness.

## Spec Reference
See SPEC.md > Caching & Persistence: "Store last-scanned timestamp per folder"

## Implementation Details

Track lastScanned date in FileNode. Show in tooltip or info panel. Use for stale detection.

## Files to Create/Modify
- `DiskSpice/Models/FileNode.swift` - Ensure lastScanned used
- `DiskSpice/Views/Components/InfoPanel.swift` - Show timestamp

## Acceptance Criteria
- [ ] Each folder tracks lastScanned timestamp
- [ ] Timestamp visible in UI (tooltip/info)
- [ ] Timestamp updates on successful scan
- [ ] Human-readable format ("2 hours ago")

## Completion Promise
`<promise>TICKET_035_COMPLETE</promise>`
