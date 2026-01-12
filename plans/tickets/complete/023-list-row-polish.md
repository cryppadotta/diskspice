# 023: Polish List Row Design

## Dependencies
- 014 (basic list view)
- 018 (file type colors)

## Task
Enhance list row design with size bar percentage indicator, file type color coding, and refined typography.

## Spec Reference
See SPEC.md > UI - List View: "Each row shows: Name, size, item count, last modified date"
See SPEC.md > UI - List View: "Size bar: visual percentage indicator relative to parent folder"

## Implementation Details

Add a size bar behind each row showing relative size. Apply file type colors to icons. Improve spacing and typography for premium feel.

```swift
struct FileListRow: View {
    let node: FileNode
    let parentTotalSize: Int64
    let isSelected: Bool
    // ... other properties

    private var sizePercentage: Double {
        guard parentTotalSize > 0 else { return 0 }
        return Double(node.size) / Double(parentTotalSize)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Size bar background
            GeometryReader { geometry in
                Rectangle()
                    .fill(FileTypeColors.color(for: node.fileType).opacity(0.1))
                    .frame(width: geometry.size.width * sizePercentage)
            }

            // Row content
            HStack(spacing: 12) {
                // Colored icon
                FileIcon(node: node)
                    .foregroundStyle(FileTypeColors.color(for: node.fileType))
                // ... rest of row
            }
        }
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/List/FileListRow.swift` - Enhanced design

## Acceptance Criteria
- [ ] Size bar shows percentage relative to parent folder
- [ ] Size bar uses file type color at low opacity
- [ ] Icons colored by file type
- [ ] Typography refined (proper weights, sizes)
- [ ] Spacing is generous but not wasteful
- [ ] Row height accommodates content comfortably
- [ ] Looks premium and polished

## Completion Promise
`<promise>TICKET_023_COMPLETE</promise>`
