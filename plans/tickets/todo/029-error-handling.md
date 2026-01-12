# 029: Handle Scan Errors with Badges

## Dependencies
- 027 (scanner UI integration)
- 024 (scanning indicators)

## Task
Display error badges on folders that failed to scan, with retry capability.

## Spec Reference
See SPEC.md > Scanning Engine: "Error handling: Failed folders show with error badge"

## Implementation Details

Track error state per folder in FileNode. Display error icon/badge. Show tooltip with error reason. Allow click to retry.

## Files to Create/Modify
- `DiskSpice/Models/FileNode.swift` - Error state in ScanStatus
- `DiskSpice/Views/List/FileListRow.swift` - Error badge
- `DiskSpice/Views/Treemap/TreemapView.swift` - Error indicator

## Acceptance Criteria
- [ ] Failed folders show error badge
- [ ] Tooltip shows error reason
- [ ] Click badge to retry scan
- [ ] Common errors handled (permission denied, not found)
- [ ] Error state persists until successful rescan

## Completion Promise
`<promise>TICKET_029_COMPLETE</promise>`
