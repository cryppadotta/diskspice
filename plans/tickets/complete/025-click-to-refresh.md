# 025: Implement Click-to-Refresh on Folders

## Dependencies
- 024 (scanning indicators)
- 010 (Swift scanner wrapper)

## Task
Allow users to click a refresh button on any folder to force an immediate rescan of that folder.

## Spec Reference
See SPEC.md > Caching & Persistence: "Manual refresh: user can click any folder to force immediate rescan"

## Implementation Details

Add refresh button/icon to folder rows in list view. On click, trigger scanner.refreshFolder(). Show scanning indicator during refresh. Update tree when complete.

## Files to Create/Modify
- `DiskSpice/Views/List/FileListRow.swift` - Add refresh button for folders
- `DiskSpice/App/AppState.swift` - Add refresh method

## Acceptance Criteria
- [ ] Folders show refresh button on hover
- [ ] Clicking refresh triggers rescan of that folder only
- [ ] Folder shows scanning indicator during refresh
- [ ] Sizes update when refresh completes
- [ ] Can refresh multiple folders simultaneously
- [ ] Refresh button has appropriate icon (arrow.clockwise)

## Completion Promise
`<promise>TICKET_025_COMPLETE</promise>`
