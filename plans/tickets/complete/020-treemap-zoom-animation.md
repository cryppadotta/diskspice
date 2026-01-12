# 020: Implement Click-to-Drill Zoom Animation

## Dependencies
- 017 (canvas treemap renderer)
- 015 (navigation state management)

## Task
Create a smooth zoom animation when clicking a folder to drill into it, providing spatial continuity.

## Spec Reference
See SPEC.md > UI - Treemap Visualization: "Click: drill into that folder's contents (zoom animation transition)"
See SPEC.md > Visual Design Goals: "Fluid 60fps animations throughout"

## Implementation Details

### TreemapContainer.swift

Wrap TreemapView with animation state management:

```swift
import SwiftUI

struct TreemapContainer: View {
    @Bindable var appState: AppState

    @State private var selectedId: UUID? = nil
    @State private var hoveredId: UUID? = nil
    @State private var zoomState: ZoomState = .idle
    @State private var zoomRect: CGRect? = nil
    @State private var viewSize: CGSize = .zero

    enum ZoomState {
        case idle
        case zoomingIn(targetRect: CGRect, targetNode: FileNode)
        case zoomingOut(fromRect: CGRect)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Current treemap
                TreemapView(
                    nodes: appState.currentChildren,
                    selectedId: $selectedId,
                    hoveredId: $hoveredId,
                    onNavigate: { node in
                        startZoomIn(to: node, in: geometry.size)
                    }
                )
                .opacity(zoomOpacity)
                .scaleEffect(zoomScale)

                // Zoom overlay during transition
                if case .zoomingIn(let targetRect, _) = zoomState {
                    ZoomOverlay(
                        rect: targetRect,
                        viewSize: geometry.size,
                        progress: zoomProgress
                    )
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
        .clipped()
    }

    // MARK: - Zoom Animation

    @State private var zoomProgress: CGFloat = 0

    private var zoomOpacity: Double {
        switch zoomState {
        case .idle: return 1
        case .zoomingIn: return 1 - Double(zoomProgress)
        case .zoomingOut: return Double(zoomProgress)
        }
    }

    private var zoomScale: CGFloat {
        switch zoomState {
        case .idle: return 1
        case .zoomingIn: return 1 + (zoomProgress * 0.5)
        case .zoomingOut: return 1.5 - (zoomProgress * 0.5)
        }
    }

    private func startZoomIn(to node: FileNode, in size: CGSize) {
        guard node.isDirectory else { return }

        // Find the rect for this node
        let rects = TreemapLayout.layout(nodes: appState.currentChildren, in: CGRect(origin: .zero, size: size))
        guard let targetRect = rects.first(where: { $0.node.id == node.id })?.frame else {
            // Fallback: navigate without animation
            appState.navigateTo(node.path)
            return
        }

        zoomState = .zoomingIn(targetRect: targetRect, targetNode: node)
        zoomProgress = 0

        withAnimation(.easeInOut(duration: 0.3)) {
            zoomProgress = 1
        }

        // Complete navigation after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.navigateTo(node.path)
            zoomState = .idle
            zoomProgress = 0
            selectedId = nil
            hoveredId = nil
        }
    }

    private func startZoomOut(in size: CGSize) {
        // For back navigation - zoom out effect
        zoomState = .zoomingOut(fromRect: CGRect(origin: .zero, size: size))
        zoomProgress = 0

        withAnimation(.easeInOut(duration: 0.25)) {
            zoomProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            zoomState = .idle
            zoomProgress = 0
        }
    }
}

// MARK: - Zoom Overlay

struct ZoomOverlay: View {
    let rect: CGRect
    let viewSize: CGSize
    let progress: CGFloat

    var body: some View {
        Canvas { context, size in
            // Draw expanding rectangle
            let expandedRect = interpolateRect(from: rect, to: CGRect(origin: .zero, size: size), progress: progress)

            let path = RoundedRectangle(cornerRadius: 8 * (1 - progress))
                .path(in: expandedRect)

            // White flash effect
            context.fill(path, with: .color(.white.opacity(0.3 * (1 - progress))))

            // Border
            context.stroke(
                path,
                with: .color(.accentColor.opacity(1 - progress)),
                lineWidth: 2
            )
        }
    }

    private func interpolateRect(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: from.minX + (to.minX - from.minX) * progress,
            y: from.minY + (to.minY - from.minY) * progress,
            width: from.width + (to.width - from.width) * progress,
            height: from.height + (to.height - from.height) * progress
        )
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    // Add mock data...

    return TreemapContainer(appState: state)
        .frame(width: 600, height: 400)
}
```

### Update ContentView to use TreemapContainer

```swift
SplitView(splitRatio: $splitRatio) {
    TreemapContainer(appState: appState)
} right: {
    FileListView(appState: appState, nodes: appState.currentChildren)
}
```

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapContainer.swift` - New file with zoom logic
- `DiskSpice/Views/ContentView.swift` - Use TreemapContainer

## Acceptance Criteria
- [ ] Double-clicking a folder triggers zoom animation
- [ ] Clicked rectangle expands to fill the view
- [ ] Current view fades/scales during transition
- [ ] Animation is smooth 60fps
- [ ] Animation duration is ~300ms
- [ ] Navigation completes after animation finishes
- [ ] Selection/hover state resets after navigation
- [ ] Works correctly at different view sizes
- [ ] Graceful fallback if rect not found

## Completion Promise
`<promise>TICKET_020_COMPLETE</promise>`
