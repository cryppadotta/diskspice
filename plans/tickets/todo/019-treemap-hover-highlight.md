# 019: Implement Treemap Hover Highlighting

## Dependencies
- 017 (canvas treemap renderer)

## Task
Add smooth hover highlighting to treemap rectangles with proper visual feedback and cursor changes.

## Spec Reference
See SPEC.md > UI - Treemap Visualization: "Hover: highlight rectangle"
See SPEC.md > Visual Design Goals: "Delightful micro-interactions on hover/click"

## Implementation Details

### Update TreemapView with enhanced hover

```swift
import SwiftUI

struct TreemapView: View {
    let nodes: [FileNode]
    @Binding var selectedId: UUID?
    @Binding var hoveredId: UUID?
    let onNavigate: (FileNode) -> Void

    @State private var rects: [TreemapRect] = []
    @State private var viewSize: CGSize = .zero
    @State private var hoverLocation: CGPoint? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main canvas
                Canvas { context, size in
                    drawTreemap(context: context, size: size)
                }

                // Hover tooltip overlay
                if let hoveredId = hoveredId,
                   let rect = rects.first(where: { $0.id == hoveredId }),
                   let location = hoverLocation {
                    TreemapTooltip(node: rect.node)
                        .position(tooltipPosition(for: location, in: geometry.size))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
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
                    withAnimation(.easeOut(duration: 0.1)) {
                        handleHover(at: location)
                    }
                case .ended:
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredId = nil
                        hoverLocation = nil
                    }
                    NSCursor.arrow.set()
                }
            }
            .onTapGesture { location in
                handleTap(at: location)
            }
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        handleDoubleTap()
                    }
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Drawing

    private func drawTreemap(context: GraphicsContext, size: CGSize) {
        for rect in rects {
            let isSelected = rect.id == selectedId
            let isHovered = rect.id == hoveredId

            drawRect(
                context: context,
                rect: rect,
                isSelected: isSelected,
                isHovered: isHovered
            )
        }
    }

    private func drawRect(
        context: GraphicsContext,
        rect: TreemapRect,
        isSelected: Bool,
        isHovered: Bool
    ) {
        let insetFrame = rect.frame.insetBy(dx: 1, dy: 1)
        let cornerRadius: CGFloat = 4

        // Hover effect: slightly larger, elevated
        let effectiveFrame: CGRect
        if isHovered {
            effectiveFrame = insetFrame.insetBy(dx: -1, dy: -1)
        } else {
            effectiveFrame = insetFrame
        }

        let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: effectiveFrame)

        // Shadow for hovered item
        if isHovered {
            context.drawLayer { ctx in
                ctx.addFilter(.shadow(color: .black.opacity(0.3), radius: 8, y: 4))
                ctx.fill(path, with: .color(.clear))
            }
        }

        // Fill
        let baseColor = FileTypeColors.color(for: rect.node.fileType, scheme: colorScheme)
        let fillOpacity: Double = isHovered ? 0.85 : 0.7
        context.fill(path, with: .color(baseColor.opacity(fillOpacity)))

        // Hover glow effect
        if isHovered {
            let glowPath = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: effectiveFrame.insetBy(dx: -2, dy: -2))
            context.stroke(
                glowPath,
                with: .color(baseColor.opacity(0.5)),
                lineWidth: 3
            )
        }

        // Selection border
        if isSelected {
            context.stroke(
                path,
                with: .color(.accentColor),
                lineWidth: 2
            )
        }

        // Labels
        if effectiveFrame.width > 60 && effectiveFrame.height > 30 {
            drawLabel(context: context, rect: rect, frame: effectiveFrame, isHovered: isHovered)
        }
    }

    private func drawLabel(
        context: GraphicsContext,
        rect: TreemapRect,
        frame: CGRect,
        isHovered: Bool
    ) {
        let fontSize = min(13, frame.height / 3)
        let weight: Font.Weight = isHovered ? .semibold : .medium

        let nameText = Text(rect.node.name)
            .font(.system(size: fontSize, weight: weight))
            .foregroundStyle(.white)

        let nameResolved = context.resolve(nameText)

        context.drawLayer { ctx in
            ctx.addFilter(.shadow(color: .black.opacity(0.6), radius: 2, y: 1))
            ctx.draw(nameResolved, at: CGPoint(x: frame.minX + 8, y: frame.minY + 8), anchor: .topLeading)
        }

        if frame.height > 50 {
            let sizeText = Text(formatBytes(rect.node.size))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))

            let sizeResolved = context.resolve(sizeText)
            let nameSize = nameResolved.measure(in: frame.size)

            context.drawLayer { ctx in
                ctx.addFilter(.shadow(color: .black.opacity(0.4), radius: 1, y: 1))
                ctx.draw(
                    sizeResolved,
                    at: CGPoint(x: frame.minX + 8, y: frame.minY + 10 + nameSize.height),
                    anchor: .topLeading
                )
            }
        }
    }

    // MARK: - Interaction

    private func handleHover(at location: CGPoint) {
        hoverLocation = location

        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            if hoveredId != rect.id {
                hoveredId = rect.id
                NSCursor.pointingHand.set()
            }
        } else {
            hoveredId = nil
            NSCursor.arrow.set()
        }
    }

    private func handleTap(at location: CGPoint) {
        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            selectedId = rect.id
        }
    }

    private func handleDoubleTap() {
        if let selectedId = selectedId,
           let rect = rects.first(where: { $0.id == selectedId }),
           rect.node.isDirectory {
            onNavigate(rect.node)
        }
    }

    private func tooltipPosition(for location: CGPoint, in size: CGSize) -> CGPoint {
        var x = location.x + 15
        var y = location.y - 30

        // Keep tooltip in bounds
        let tooltipWidth: CGFloat = 180
        let tooltipHeight: CGFloat = 60

        if x + tooltipWidth > size.width {
            x = location.x - tooltipWidth - 15
        }
        if y < 0 {
            y = location.y + 30
        }

        return CGPoint(x: x + tooltipWidth/2, y: y + tooltipHeight/2)
    }

    // ... rest of implementation
}

// MARK: - Tooltip

struct TreemapTooltip: View {
    let node: FileNode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Text(formatBytes(node.size))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if node.isDirectory {
                Text("\(node.itemCount) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .frame(width: 180)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapView.swift` - Enhanced hover effects
- `DiskSpice/Views/Treemap/TreemapTooltip.swift` - New file (or inline)

## Acceptance Criteria
- [ ] Hovered rectangle visually elevates (slight scale/shadow)
- [ ] Hovered rectangle has glow effect matching its color
- [ ] Cursor changes to pointing hand on hover
- [ ] Smooth animation when hover starts/ends
- [ ] Tooltip appears near cursor showing name, size, item count
- [ ] Tooltip stays within view bounds
- [ ] Tooltip has blur/material background
- [ ] Labels become bolder on hover
- [ ] Performance remains 60fps with hover effects

## Completion Promise
`<promise>TICKET_019_COMPLETE</promise>`
