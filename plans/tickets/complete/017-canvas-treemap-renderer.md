# 017: Create Canvas-Based Treemap Renderer

## Dependencies
- 016 (squarified treemap algorithm)

## Task
Build the SwiftUI Canvas view that renders the treemap rectangles with proper styling, labels, and performance optimization.

## Spec Reference
See SPEC.md > UI Framework: "SwiftUI Canvas for treemap visualization (hardware accelerated drawing)"
See SPEC.md > Visual Design Goals: shadows, gradients, depth

## Implementation Details

### TreemapView.swift

```swift
import SwiftUI

struct TreemapView: View {
    let nodes: [FileNode]
    let selectedId: UUID?
    let hoveredId: UUID?
    let onSelect: (FileNode) -> Void
    let onNavigate: (FileNode) -> Void
    let onHover: (FileNode?) -> Void

    @State private var rects: [TreemapRect] = []
    @State private var viewSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawTreemap(context: context, size: size)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                recalculateLayout(size: newSize)
            }
            .onChange(of: nodes) { _, _ in
                recalculateLayout(size: viewSize)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    handleHover(at: location)
                case .ended:
                    onHover(nil)
                }
            }
            .onTapGesture { location in
                handleTap(at: location)
            }
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        // Double tap - need to track location differently
                        // This is handled via onTapGesture modifier
                    }
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Drawing

    private func drawTreemap(context: GraphicsContext, size: CGSize) {
        for rect in rects {
            drawRect(context: context, rect: rect)
        }
    }

    private func drawRect(context: GraphicsContext, rect: TreemapRect) {
        let isSelected = rect.id == selectedId
        let isHovered = rect.id == hoveredId

        // Inset slightly for gaps between rectangles
        let insetFrame = rect.frame.insetBy(dx: 1, dy: 1)
        let path = RoundedRectangle(cornerRadius: 4).path(in: insetFrame)

        // Fill color based on file type
        let fillColor = colorForFileType(rect.node.fileType)
        let adjustedColor = isHovered ? fillColor.opacity(0.9) : fillColor.opacity(0.7)

        // Draw fill
        context.fill(path, with: .color(adjustedColor))

        // Draw border for selected
        if isSelected {
            context.stroke(
                path,
                with: .color(.accentColor),
                lineWidth: 2
            )
        } else if isHovered {
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.5)),
                lineWidth: 1
            )
        }

        // Draw label if rectangle is large enough
        if insetFrame.width > 60 && insetFrame.height > 30 {
            drawLabel(context: context, rect: rect, frame: insetFrame)
        }
    }

    private func drawLabel(context: GraphicsContext, rect: TreemapRect, frame: CGRect) {
        let name = rect.node.name
        let size = formatBytes(rect.node.size)

        // Name label
        let nameText = Text(name)
            .font(.system(size: min(13, frame.height / 3), weight: .medium))
            .foregroundStyle(.white)

        let nameResolved = context.resolve(nameText)
        let nameSize = nameResolved.measure(in: frame.size)

        let namePoint = CGPoint(
            x: frame.minX + 8,
            y: frame.minY + 8
        )

        // Draw with shadow for readability
        context.drawLayer { ctx in
            ctx.addFilter(.shadow(color: .black.opacity(0.5), radius: 1, y: 1))
            ctx.draw(nameResolved, at: namePoint, anchor: .topLeading)
        }

        // Size label (if room)
        if frame.height > 50 {
            let sizeText = Text(size)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))

            let sizeResolved = context.resolve(sizeText)
            let sizePoint = CGPoint(
                x: frame.minX + 8,
                y: frame.minY + 8 + nameSize.height + 2
            )

            context.drawLayer { ctx in
                ctx.addFilter(.shadow(color: .black.opacity(0.3), radius: 1, y: 1))
                ctx.draw(sizeResolved, at: sizePoint, anchor: .topLeading)
            }
        }
    }

    // MARK: - Layout

    private func recalculateLayout(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let bounds = CGRect(origin: .zero, size: size)
        rects = TreemapLayout.layout(nodes: nodes, in: bounds)
    }

    // MARK: - Interaction

    private func handleHover(at location: CGPoint) {
        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            onHover(rect.node)
        } else {
            onHover(nil)
        }
    }

    private func handleTap(at location: CGPoint) {
        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            onSelect(rect.node)
        }
    }

    // MARK: - Helpers

    private func colorForFileType(_ type: FileType) -> Color {
        switch type {
        case .video: return .blue
        case .audio: return .purple
        case .image: return .green
        case .code: return .orange
        case .archive: return .brown
        case .application: return .red
        case .system: return .gray
        case .cache: return .yellow
        case .document: return .teal
        case .other: return Color(nsColor: .systemGray)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Preview

#Preview {
    let nodes = [
        FileNode(path: URL(fileURLWithPath: "/Videos"), name: "Videos", size: 50_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Photos"), name: "Photos", size: 30_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Documents"), name: "Documents", size: 15_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Music"), name: "Music", size: 10_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Downloads"), name: "Downloads", size: 5_000_000_000, isDirectory: true),
    ].map { node in
        var n = node
        n.fileType = [.video, .image, .document, .audio, .archive][Int.random(in: 0..<5)]
        return n
    }

    return TreemapView(
        nodes: nodes,
        selectedId: nil,
        hoveredId: nil,
        onSelect: { _ in },
        onNavigate: { _ in },
        onHover: { _ in }
    )
    .frame(width: 600, height: 400)
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapView.swift` - New file

## Acceptance Criteria
- [ ] Canvas renders rectangles for all nodes
- [ ] Rectangles have rounded corners and gaps between them
- [ ] Each rectangle colored by file type
- [ ] Labels show name and size (when rectangle is large enough)
- [ ] Labels have shadow for readability over colors
- [ ] Selected rectangle has accent color border
- [ ] Hovered rectangle has subtle highlight
- [ ] Layout recalculates when view size changes
- [ ] Layout recalculates when nodes change
- [ ] 60fps performance with reasonable node count

## Completion Promise
`<promise>TICKET_017_COMPLETE</promise>`
