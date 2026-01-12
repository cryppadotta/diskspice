# 021: Handle Small Items Grouping ("Other")

## Dependencies
- 016 (squarified treemap algorithm)
- 017 (canvas treemap renderer)

## Task
Implement grouping of small items that would be too tiny to render meaningfully into a single "Other (N items, X MB)" rectangle.

## Spec Reference
See SPEC.md > UI - Treemap Visualization: "Items below visual threshold grouped into 'Other (N items, X MB)'"

## Implementation Details

### Update TreemapLayout.swift

```swift
import Foundation
import CoreGraphics

struct TreemapRect: Identifiable {
    let id: UUID
    let node: FileNode
    var frame: CGRect
    let isOtherGroup: Bool

    init(id: UUID, node: FileNode, frame: CGRect, isOtherGroup: Bool = false) {
        self.id = id
        self.node = node
        self.frame = frame
        self.isOtherGroup = isOtherGroup
    }
}

/// Represents grouped small items
struct OtherGroup {
    let items: [FileNode]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var itemCount: Int { items.count }

    func asFileNode() -> FileNode {
        var node = FileNode(
            path: URL(fileURLWithPath: "/__other__"),
            name: "Other (\(itemCount) items)",
            size: totalSize,
            isDirectory: false
        )
        node.fileType = .other
        node.itemCount = itemCount
        return node
    }
}

extension TreemapLayout {
    /// Minimum pixel size for a rectangle to be individually rendered
    static let minimumRectSize: CGFloat = 20

    /// Maximum number of items to show before grouping
    static let maxVisibleItems = 100

    static func layoutWithGrouping(
        nodes: [FileNode],
        in bounds: CGRect
    ) -> (rects: [TreemapRect], otherGroup: OtherGroup?) {
        guard !nodes.isEmpty else { return ([], nil) }

        let validNodes = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !validNodes.isEmpty else { return ([], nil) }

        let totalSize = validNodes.reduce(0) { $0 + $1.size }
        let minAreaRatio = (minimumRectSize * minimumRectSize) / (bounds.width * bounds.height)
        let minSize = Int64(Double(totalSize) * Double(minAreaRatio))

        // Split into visible and grouped items
        var visibleNodes: [FileNode] = []
        var groupedNodes: [FileNode] = []

        for (index, node) in validNodes.enumerated() {
            // Group if: too small OR too many items
            if node.size < minSize || index >= maxVisibleItems {
                groupedNodes.append(node)
            } else {
                visibleNodes.append(node)
            }
        }

        // Create "Other" group if there are grouped items
        var nodesToLayout = visibleNodes
        var otherGroup: OtherGroup? = nil

        if !groupedNodes.isEmpty {
            otherGroup = OtherGroup(items: groupedNodes)
            nodesToLayout.append(otherGroup!.asFileNode())
        }

        // Layout all nodes including Other group
        let newTotalSize = nodesToLayout.reduce(0) { $0 + $1.size }
        var rects = squarify(nodes: nodesToLayout, totalSize: newTotalSize, bounds: bounds)

        // Mark the Other group rect
        if let otherGroup = otherGroup {
            for i in rects.indices {
                if rects[i].node.path.path == "/__other__" {
                    rects[i] = TreemapRect(
                        id: rects[i].id,
                        node: rects[i].node,
                        frame: rects[i].frame,
                        isOtherGroup: true
                    )
                }
            }
        }

        return (rects, otherGroup)
    }
}
```

### Update TreemapView to handle Other group

```swift
// In TreemapView.swift

@State private var otherGroup: OtherGroup? = nil
@State private var showingOtherPopover = false

private func recalculateLayout(size: CGSize) {
    guard size.width > 0 && size.height > 0 else { return }
    let bounds = CGRect(origin: .zero, size: size)
    let result = TreemapLayout.layoutWithGrouping(nodes: nodes, in: bounds)
    rects = result.rects
    otherGroup = result.otherGroup
}

private func drawRect(/* ... */) {
    // ... existing drawing code ...

    // Special styling for "Other" group
    if rect.isOtherGroup {
        drawOtherGroupRect(context: context, rect: rect, frame: effectiveFrame, isHovered: isHovered)
        return
    }

    // ... rest of regular drawing
}

private func drawOtherGroupRect(
    context: GraphicsContext,
    rect: TreemapRect,
    frame: CGRect,
    isHovered: Bool
) {
    let path = RoundedRectangle(cornerRadius: 4).path(in: frame)

    // Striped/hatched pattern for "Other"
    context.fill(path, with: .color(Color.gray.opacity(0.3)))

    // Draw diagonal lines pattern
    context.clip(to: path)
    let stripeSpacing: CGFloat = 8
    var x = frame.minX - frame.height
    while x < frame.maxX {
        var stripePath = Path()
        stripePath.move(to: CGPoint(x: x, y: frame.maxY))
        stripePath.addLine(to: CGPoint(x: x + frame.height, y: frame.minY))
        context.stroke(stripePath, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)
        x += stripeSpacing
    }
    context.resetClip()

    // Border
    if isHovered {
        context.stroke(path, with: .color(.accentColor), lineWidth: 2)
    } else {
        context.stroke(path, with: .color(Color.gray.opacity(0.4)), lineWidth: 1)
    }

    // Label
    if frame.width > 80 && frame.height > 40 {
        let text = Text("Other (\(rect.node.itemCount) items)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

        let resolved = context.resolve(text)
        context.draw(resolved, at: CGPoint(x: frame.midX, y: frame.midY), anchor: .center)
    }
}

// Handle click on Other group to show list
private func handleTap(at location: CGPoint) {
    if let rect = rects.first(where: { $0.frame.contains(location) }) {
        if rect.isOtherGroup {
            showingOtherPopover = true
        } else {
            selectedId = rect.id
        }
    }
}
```

### OtherItemsPopover.swift

```swift
import SwiftUI

struct OtherItemsPopover: View {
    let items: [FileNode]
    let onSelect: (FileNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Other Items (\(items.count))")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items.sorted { $0.size > $1.size }) { node in
                        OtherItemRow(node: node)
                            .onTapGesture {
                                onSelect(node)
                            }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 300)
    }
}

struct OtherItemRow: View {
    let node: FileNode

    var body: some View {
        HStack {
            Image(systemName: node.isDirectory ? "folder" : "doc")
                .foregroundStyle(.secondary)

            Text(node.name)
                .lineLimit(1)

            Spacer()

            Text(formatBytes(node.size))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapLayout.swift` - Add grouping logic
- `DiskSpice/Views/Treemap/TreemapView.swift` - Handle Other group display
- `DiskSpice/Views/Treemap/OtherItemsPopover.swift` - New file

## Acceptance Criteria
- [ ] Items smaller than minimum visible size are grouped
- [ ] Items beyond maxVisibleItems count are grouped
- [ ] "Other" rectangle shows item count and total size
- [ ] "Other" has distinct visual style (hatched/striped pattern)
- [ ] Clicking "Other" shows popover with list of items
- [ ] Popover list is scrollable and sorted by size
- [ ] Selecting item from popover navigates to it
- [ ] Grouping adapts when view is resized

## Completion Promise
`<promise>TICKET_021_COMPLETE</promise>`
