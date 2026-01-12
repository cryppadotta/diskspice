# 048: Add Bulk Select and Delete for Utilities

## Dependencies
- 047 (stale node_modules finder)
- 039 (move to trash)

## Task
Allow selecting multiple items in utilities panel and deleting them in bulk.

## Spec Reference
See SPEC.md > Smart Utilities Panel: "Bulk select and delete"

## Implementation Details

Add checkboxes to utility results. "Select All" / "Select None" buttons. "Delete Selected" button with confirmation showing total size.

## Files to Create/Modify
- `DiskSpice/Views/Utilities/NodeModulesFinder.swift` - Add selection
- `DiskSpice/Views/Utilities/BulkDeleteConfirmation.swift` - New file

## Acceptance Criteria
- [ ] Checkboxes on each item
- [ ] Select All / Select None buttons
- [ ] Selected count and total size shown
- [ ] Delete Selected with confirmation
- [ ] Progress during bulk delete
- [ ] Summary after completion

## Completion Promise
`<promise>TICKET_048_COMPLETE</promise>`
