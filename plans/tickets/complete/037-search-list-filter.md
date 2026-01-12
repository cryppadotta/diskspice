# 037: Implement Search Filtering in List View

## Dependencies
- 036 (search bar)
- 014 (basic list view)

## Task
Filter list view to show only items matching search query.

## Spec Reference
See SPEC.md > Search: "List filters to show only matching items"

## Implementation Details

Filter currentChildren by name containing searchQuery (case-insensitive). Search recursively to find matches in subfolders. Show match count.

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Add filtered computed property
- `DiskSpice/Views/List/FileListView.swift` - Use filtered nodes

## Acceptance Criteria
- [ ] List shows only matching items when searching
- [ ] Search is case-insensitive
- [ ] Recursive search finds nested matches
- [ ] Match count displayed
- [ ] Clear search shows all items

## Completion Promise
`<promise>TICKET_037_COMPLETE</promise>`
