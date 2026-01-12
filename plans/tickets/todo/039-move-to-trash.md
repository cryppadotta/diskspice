# 039: Implement Move to Trash

## Dependencies
- 014 (basic list view)
- 022 (selection sync)

## Task
Implement deleting selected item by moving to Trash.

## Spec Reference
See SPEC.md > File Operations: "Move to Trash: Primary deletion method"

## Implementation Details

Use FileManager.trashItem(). Add Delete key binding. Show confirmation for large items. Animate removal from UI.

```swift
func moveToTrash(node: FileNode) throws {
    var trashedURL: NSURL?
    try FileManager.default.trashItem(at: node.path, resultingItemURL: &trashedURL)
}
```

## Files to Create/Modify
- `DiskSpice/Services/FileOperations.swift` - New file
- `DiskSpice/App/AppState.swift` - Add delete method

## Acceptance Criteria
- [ ] Delete key moves selected item to Trash
- [ ] Confirmation dialog for items > 100MB
- [ ] Item removed from UI after deletion
- [ ] Error handling for permission denied
- [ ] Undo via system Trash (macOS handles)

## Completion Promise
`<promise>TICKET_039_COMPLETE</promise>`
