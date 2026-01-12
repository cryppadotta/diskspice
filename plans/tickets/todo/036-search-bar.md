# 036: Create Search Bar Component

## Dependencies
- 005 (main window structure)

## Task
Add search bar to navigation area for filtering files by name.

## Spec Reference
See SPEC.md > Search: "Search bar: Filter and highlight matches"

## Implementation Details

Add TextField with search icon. Bind to appState.searchQuery. Support Cmd+F shortcut.

## Files to Create/Modify
- `DiskSpice/Views/Components/SearchBar.swift` - New file
- `DiskSpice/Views/Components/BreadcrumbBar.swift` - Add search bar

## Acceptance Criteria
- [ ] Search bar in navigation area
- [ ] Cmd+F focuses search
- [ ] Escape clears and unfocuses
- [ ] Placeholder text "Search"
- [ ] Clear button when has text

## Completion Promise
`<promise>TICKET_036_COMPLETE</promise>`
