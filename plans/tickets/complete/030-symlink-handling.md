# 030: Implement Symlink/Hardlink Handling

## Dependencies
- 027 (scanner UI integration)

## Task
Display symlinks with special indicator, show target size but don't count toward parent total.

## Spec Reference
See SPEC.md > Scanning Engine: "Symlinks/hardlinks: Show with special indicator, display target size but don't add to parent total"

## Implementation Details

Mark symlinks in FileNode.isSymlink. Show link icon. Display size but exclude from parent sum calculations. Tooltip shows target path.

## Files to Create/Modify
- `DiskSpice/Views/List/FileListRow.swift` - Symlink icon
- `DiskSpice/Views/Treemap/TreemapView.swift` - Symlink styling
- `DiskSpice/Models/FileNode.swift` - Ensure isSymlink is used

## Acceptance Criteria
- [ ] Symlinks show link icon/indicator
- [ ] Symlink size displayed but not added to parent
- [ ] Tooltip shows "Symlink to: /path/to/target"
- [ ] Visual distinction from regular files
- [ ] Hardlinks handled similarly if detectable

## Completion Promise
`<promise>TICKET_030_COMPLETE</promise>`
