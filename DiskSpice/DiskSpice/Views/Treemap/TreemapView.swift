import SwiftUI

struct TreemapView: View {
    let nodes: [FileNode]
    let selectedId: UUID?
    let hoveredId: UUID?
    let onSelect: (FileNode) -> Void
    let onNavigate: (FileNode) -> Void
    let onHover: (FileNode?) -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var rects: [TreemapRect] = []
    @State private var viewSize: CGSize = .zero
    @State private var hoverLocation: CGPoint? = nil

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
                        .animation(.easeOut(duration: 0.15), value: hoveredId)
                }
            }
            .onAppear {
                viewSize = geometry.size
                recalculateLayout(size: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                recalculateLayout(size: newSize)
            }
            .onChange(of: nodes) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    recalculateLayout(size: viewSize)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    withAnimation(.easeOut(duration: 0.1)) {
                        handleHover(at: location)
                    }
                case .ended:
                    withAnimation(.easeOut(duration: 0.15)) {
                        onHover(nil)
                        hoverLocation = nil
                    }
                    NSCursor.arrow.set()
                }
            }
            .contentShape(Rectangle()) // Enable hit testing on full area
            .onTapGesture { location in
                handleTap(at: location)
            }
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

        // Special rendering for "Other" group
        if rect.isOtherGroup {
            drawOtherGroupRect(context: context, frame: effectiveFrame, isHovered: isHovered, isSelected: isSelected, itemCount: rect.node.itemCount)
            return
        }

        let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: effectiveFrame)

        // Shadow for hovered item
        if isHovered {
            context.drawLayer { ctx in
                ctx.addFilter(.shadow(color: .black.opacity(0.3), radius: 8, y: 4))
                let shadowPath = RoundedRectangle(cornerRadius: cornerRadius).path(in: effectiveFrame)
                ctx.fill(shadowPath, with: .color(Color.black.opacity(0.01)))
            }
        }

        // Fill
        let baseColor = colorForFileType(rect.node.fileType)
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

        // Error indicator
        if case .error = rect.node.scanStatus {
            drawErrorBadge(context: context, frame: effectiveFrame)
        }

        // Symlink indicator - dashed border and link badge
        if rect.node.isSymlink {
            drawSymlinkIndicator(context: context, frame: effectiveFrame, cornerRadius: cornerRadius)
        }
    }

    private func drawSymlinkIndicator(context: GraphicsContext, frame: CGRect, cornerRadius: CGFloat) {
        // Dashed border
        let dashedPath = RoundedRectangle(cornerRadius: cornerRadius).path(in: frame)
        context.stroke(
            dashedPath,
            with: .color(.purple.opacity(0.6)),
            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
        )

        // Link badge in top-left corner
        let badgeSize: CGFloat = 14
        let badgeRect = CGRect(
            x: frame.minX + 4,
            y: frame.minY + 4,
            width: badgeSize,
            height: badgeSize
        )

        let circlePath = Circle().path(in: badgeRect)
        context.fill(circlePath, with: .color(.purple.opacity(0.8)))

        let linkText = Text("🔗")
            .font(.system(size: 8))
        let resolved = context.resolve(linkText)
        context.draw(resolved, at: CGPoint(x: badgeRect.midX, y: badgeRect.midY), anchor: .center)
    }

    private func drawErrorBadge(context: GraphicsContext, frame: CGRect) {
        let badgeSize: CGFloat = 16
        let badgeRect = CGRect(
            x: frame.maxX - badgeSize - 4,
            y: frame.minY + 4,
            width: badgeSize,
            height: badgeSize
        )

        // Background circle
        let circlePath = Circle().path(in: badgeRect)
        context.fill(circlePath, with: .color(.red))

        // Exclamation mark
        let text = Text("!")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
        let resolved = context.resolve(text)
        context.draw(resolved, at: CGPoint(x: badgeRect.midX, y: badgeRect.midY), anchor: .center)
    }

    private func drawOtherGroupRect(
        context: GraphicsContext,
        frame: CGRect,
        isHovered: Bool,
        isSelected: Bool,
        itemCount: Int
    ) {
        let cornerRadius: CGFloat = 4
        let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: frame)

        // Base fill - gray with stripes
        context.fill(path, with: .color(Color.gray.opacity(isHovered ? 0.4 : 0.3)))

        // Draw diagonal stripes pattern
        context.drawLayer { ctx in
            ctx.clip(to: path)
            let stripeSpacing: CGFloat = 8
            var x = frame.minX - frame.height
            while x < frame.maxX + stripeSpacing {
                var stripePath = Path()
                stripePath.move(to: CGPoint(x: x, y: frame.maxY))
                stripePath.addLine(to: CGPoint(x: x + frame.height, y: frame.minY))
                ctx.stroke(stripePath, with: .color(Color.gray.opacity(0.3)), lineWidth: 1)
                x += stripeSpacing
            }
        }

        // Border
        if isSelected {
            context.stroke(path, with: .color(.accentColor), lineWidth: 2)
        } else if isHovered {
            context.stroke(path, with: .color(.accentColor.opacity(0.7)), lineWidth: 2)
        } else {
            context.stroke(path, with: .color(Color.gray.opacity(0.5)), lineWidth: 1)
        }

        // Label
        if frame.width > 80 && frame.height > 40 {
            let text = Text("Other (\(itemCount) items)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            let resolved = context.resolve(text)
            context.draw(resolved, at: CGPoint(x: frame.midX, y: frame.midY), anchor: .center)
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

    // MARK: - Layout

    private func recalculateLayout(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let bounds = CGRect(origin: .zero, size: size)
        rects = TreemapLayout.layout(nodes: nodes, in: bounds)
    }

    // MARK: - Interaction

    private func handleHover(at location: CGPoint) {
        hoverLocation = location

        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            if hoveredId != rect.id {
                onHover(rect.node)
                NSCursor.pointingHand.set()
            }
        } else {
            onHover(nil)
            NSCursor.arrow.set()
        }
    }

    private func handleTap(at location: CGPoint) {
        debugLog("handleTap at \(location), rects.count=\(rects.count)", category: "TAP")

        if let rect = rects.first(where: { $0.frame.contains(location) }) {
            debugLog("Found rect: \(rect.node.name), isDirectory=\(rect.node.isDirectory), isOtherGroup=\(rect.isOtherGroup)", category: "TAP")

            // Single-click navigates into folders, selects files
            if rect.node.isDirectory && !rect.isOtherGroup {
                debugLog("Calling onNavigate for \(rect.node.path.path)", category: "TAP")
                onNavigate(rect.node)
            } else {
                debugLog("Calling onSelect for \(rect.node.name)", category: "TAP")
                onSelect(rect.node)
            }
        } else {
            debugLog("No rect found at location", category: "TAP")
        }
    }

    private func tooltipPosition(for location: CGPoint, in size: CGSize) -> CGPoint {
        let tooltipWidth: CGFloat = 180
        let tooltipHeight: CGFloat = 70

        var x = location.x + 15 + tooltipWidth / 2
        var y = location.y - 30

        // Keep tooltip in bounds
        if x + tooltipWidth / 2 > size.width {
            x = location.x - tooltipWidth / 2 - 15
        }
        if x - tooltipWidth / 2 < 0 {
            x = tooltipWidth / 2 + 10
        }
        if y - tooltipHeight / 2 < 0 {
            y = location.y + tooltipHeight / 2 + 30
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Helpers

    private func colorForFileType(_ type: FileType) -> Color {
        FileTypeColors.color(for: type, scheme: colorScheme)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
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

// MARK: - Preview

#Preview {
    let nodes = [
        FileNode(path: URL(fileURLWithPath: "/Videos"), name: "Videos", size: 50_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Photos"), name: "Photos", size: 30_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Documents"), name: "Documents", size: 15_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Music"), name: "Music", size: 10_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/Downloads"), name: "Downloads", size: 5_000_000_000, isDirectory: true),
    ]

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
