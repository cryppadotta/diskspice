# 042: Block Deletion During Scan

## Dependencies
- 039 (move to trash)
- 024 (scanning indicators)

## Task
Prevent deletion of items that are currently being scanned.

## Spec Reference
See SPEC.md > File Operations: "Delete during scan: Block until folder scan completes"

## Implementation Details

Check scanStatus before allowing delete. Show alert if scanning. Option to wait or cancel.

## Files to Create/Modify
- `DiskSpice/Services/FileOperations.swift` - Add scan check
- `DiskSpice/Views/Components/ScanningAlert.swift` - Alert view

## Acceptance Criteria
- [ ] Cannot delete folder that is scanning
- [ ] Alert shown explaining why
- [ ] Can delete after scan completes
- [ ] Option to cancel scan then delete
- [ ] Non-scanning items delete normally

## Completion Promise
`<promise>TICKET_042_COMPLETE</promise>`
