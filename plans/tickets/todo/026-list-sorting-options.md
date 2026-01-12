# 026: Add List Sorting Options

## Dependencies
- 014 (basic list view)

## Task
Allow sorting by different columns: size (default), name, date modified, item count.

## Spec Reference
See SPEC.md > UI - List View: "Sorted by size (largest first)" - make this the default but allow alternatives.

## Implementation Details

Make column headers clickable to sort. Show sort indicator (arrow up/down). Remember sort preference in AppState.

```swift
enum SortField: String, CaseIterable {
    case size, name, modified, itemCount
}

enum SortOrder {
    case ascending, descending
}
```

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Add sort state
- `DiskSpice/Views/List/FileListHeader.swift` - Clickable sortable headers
- `DiskSpice/Views/List/FileListView.swift` - Apply sort

## Acceptance Criteria
- [ ] Clicking column header sorts by that column
- [ ] Clicking again reverses sort order
- [ ] Sort indicator shows current sort column and direction
- [ ] Size (descending) is default sort
- [ ] Sort is fast even with many items
- [ ] Folders can optionally be sorted separately from files

## Completion Promise
`<promise>TICKET_026_COMPLETE</promise>`
