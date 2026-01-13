import SwiftUI

struct TreemapContainer: View {
    @Bindable var appState: AppState

    @State private var hoveredId: UUID? = nil
    @State private var zoomState: ZoomState = .idle
    @State private var viewSize: CGSize = .zero
    @State private var zoomProgress: CGFloat = 0

    enum ZoomState: Equatable {
        case idle
        case zoomingIn(targetRect: CGRect, targetPath: URL)
        case zoomingOut(fromRect: CGRect)

        static func == (lhs: ZoomState, rhs: ZoomState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.zoomingIn(let r1, let p1), .zoomingIn(let r2, let p2)):
                return r1 == r2 && p1 == p2
            case (.zoomingOut(let r1), .zoomingOut(let r2)):
                return r1 == r2
            default:
                return false
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Current treemap
                TreemapView(
                    nodes: appState.currentChildren,
                    selectedId: appState.selectedNode?.id,
                    hoveredId: hoveredId,
                    onSelect: { node in
                        appState.selectNode(node)
                    },
                    onNavigate: { node in
                        startZoomIn(to: node, in: geometry.size)
                    },
                    onHover: { node in
                        hoveredId = node?.id
                    },
                    onDelete: { node in
                        appState.deleteNode(node)
                    },
                    onRevealInFinder: { node in
                        FileOperations.revealInFinder(node.path)
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
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
        .clipped()
    }

    // MARK: - Zoom Animation

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

        zoomState = .zoomingIn(targetRect: targetRect, targetPath: node.path)
        zoomProgress = 0

        withAnimation(.easeInOut(duration: 0.3)) {
            zoomProgress = 1
        }

        // Complete navigation after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.navigateTo(node.path)
            zoomState = .idle
            zoomProgress = 0
            hoveredId = nil
        }
    }

    func startZoomOut(in size: CGSize) {
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
            let expandedRect = interpolateRect(
                from: rect,
                to: CGRect(origin: .zero, size: size),
                progress: progress
            )

            let cornerRadius = 8 * (1 - progress)
            let path = RoundedRectangle(cornerRadius: cornerRadius)
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
        .allowsHitTesting(false)
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
    TreemapContainerPreview()
}

@MainActor
private struct TreemapContainerPreview: View {
    @State private var state: AppState

    init() {
        let state = AppState()
        let mockChildren: [FileNode] = [
            FileNode(path: URL(fileURLWithPath: "/Users"), name: "Users", size: 150_000_000_000, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/Applications"), name: "Applications", size: 50_000_000_000, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/Library"), name: "Library", size: 30_000_000_000, isDirectory: true),
        ]
        state.updateChildren(at: URL(fileURLWithPath: "/"), children: mockChildren)
        _state = State(initialValue: state)
    }

    var body: some View {
        TreemapContainer(appState: state)
            .frame(width: 600, height: 400)
    }
}
