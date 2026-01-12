# 040: Create Context Menu

## Dependencies
- 039 (move to trash)

## Task
Add right-click context menu with "Move to Trash" and "Reveal in Finder" options.

## Spec Reference
See SPEC.md > File Operations: "Right-click context menu: Move to Trash, Reveal in Finder"

## Implementation Details

Add .contextMenu to list rows and treemap items. Include: Move to Trash, Reveal in Finder, Copy Path, Refresh.

```swift
.contextMenu {
    Button("Reveal in Finder") { NSWorkspace.shared.selectFile(node.path.path, inFileViewerRootedAtPath: "") }
    Button("Move to Trash") { deleteNode(node) }
    Divider()
    Button("Copy Path") { NSPasteboard.general.setString(node.path.path, forType: .string) }
}
```

## Files to Create/Modify
- `DiskSpice/Views/List/FileListRow.swift` - Add context menu
- `DiskSpice/Views/Treemap/TreemapView.swift` - Add context menu

## Acceptance Criteria
- [ ] Right-click shows context menu
- [ ] "Reveal in Finder" opens Finder and selects item
- [ ] "Move to Trash" deletes item
- [ ] "Copy Path" copies full path
- [ ] Context menu styled appropriately

## Completion Promise
`<promise>TICKET_040_COMPLETE</promise>`
