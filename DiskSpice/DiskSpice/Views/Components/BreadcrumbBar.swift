import SwiftUI

struct BreadcrumbBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Back button
            NavigationButton(
                icon: "chevron.left",
                isEnabled: appState.navigationState.canGoBack
            ) {
                appState.goBack()
            }

            // Up button
            NavigationButton(
                icon: "chevron.up",
                isEnabled: canGoUp
            ) {
                appState.goUp()
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // Breadcrumbs
            BreadcrumbPath(
                appState: appState,
                breadcrumbs: appState.navigationState.breadcrumbs,
                onSelect: { url in
                    appState.navigateTo(url)
                }
            )

            Spacer()

            // Search bar
            SearchBar(text: $appState.searchQuery)
                .frame(width: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var canGoUp: Bool {
        appState.navigationState.currentPath.path != "/"
    }
}

// MARK: - Navigation Button

struct NavigationButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var backgroundColor: Color {
        if isPressed && isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        } else if isHovering && isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Breadcrumb Path

struct BreadcrumbPath: View {
    let appState: AppState
    let breadcrumbs: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, url in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    BreadcrumbItem(
                        appState: appState,
                        url: url,
                        name: displayName(for: url),
                        isLast: index == breadcrumbs.count - 1
                    ) {
                        onSelect(url)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }
        return url.lastPathComponent
    }
}

// MARK: - Breadcrumb Item

struct BreadcrumbItem: View {
    let appState: AppState
    let url: URL
    let name: String
    let isLast: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isLast ? .semibold : .regular))
                .foregroundStyle(isLast ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovering ? Color(nsColor: .controlBackgroundColor) : .clear)
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let node = appState.nodeForPath(url) {
                Button("Move to Trash", systemImage: "trash") {
                    appState.deleteNode(node)
                }
            }
            Button("Open Enclosing Folder in Finder", systemImage: "folder") {
                FileOperations.revealInFinder(url)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    BreadcrumbBar(appState: state)
        .frame(width: 600)
}
