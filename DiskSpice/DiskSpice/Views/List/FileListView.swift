import SwiftUI

struct FileListView: View {
    @Bindable var appState: AppState
    let nodes: [FileNode]

    private var parentTotalSize: Int64 {
        // Exclude symlinks from total to avoid double-counting
        nodes.reduce(0) { $0 + $1.effectiveSize }
    }

    private var sortedNodes: [FileNode] {
        appState.sortedNodes(for: appState.navigationState.currentPath, nodes: nodes)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            FileListHeader(
                sortField: appState.sortField,
                sortOrder: appState.sortOrder,
                onSort: { field in appState.toggleSort(for: field) }
            )

            // List with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedNodes) { node in
                            FileListRow(
                                node: node,
                                parentTotalSize: parentTotalSize,
                                isSelected: appState.selectedNode?.id == node.id,
                                isActivelyScanning: appState.isCurrentlyScanning(path: node.path),
                                onSelect: {
                                    appState.selectNode(node)
                                },
                                onNavigate: {
                                    if node.isDirectory {
                                        appState.navigateTo(node.path)
                                    }
                                }
                            )
                            .id(node.id)
                        }
                    }
                }
                .onChange(of: appState.selectedNode?.id) { _, newId in
                    // Scroll to selected item when selection changes (e.g., from treemap)
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - List Header

struct FileListHeader: View {
    let sortField: SortField
    let sortOrder: SortOrder
    let onSort: (SortField) -> Void

    var body: some View {
        HStack(spacing: 0) {
            SortableColumnHeader(
                title: "Name",
                field: .name,
                currentField: sortField,
                sortOrder: sortOrder,
                alignment: .leading,
                onSort: onSort
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            SortableColumnHeader(
                title: "Size",
                field: .size,
                currentField: sortField,
                sortOrder: sortOrder,
                alignment: .trailing,
                onSort: onSort
            )
            .frame(width: 80)

            SortableColumnHeader(
                title: "Items",
                field: .itemCount,
                currentField: sortField,
                sortOrder: sortOrder,
                alignment: .trailing,
                onSort: onSort
            )
            .frame(width: 60)

            SortableColumnHeader(
                title: "Modified",
                field: .modified,
                currentField: sortField,
                sortOrder: sortOrder,
                alignment: .trailing,
                onSort: onSort
            )
            .frame(width: 100)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }
}

// MARK: - Sortable Column Header

struct SortableColumnHeader: View {
    let title: String
    let field: SortField
    let currentField: SortField
    let sortOrder: SortOrder
    let alignment: Alignment
    let onSort: (SortField) -> Void

    @State private var isHovering = false

    private var isActive: Bool {
        field == currentField
    }

    var body: some View {
        Button {
            onSort(field)
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing {
                    Spacer(minLength: 0)
                }

                Text(title)
                    .foregroundStyle(isActive ? .primary : .secondary)

                if isActive {
                    Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.primary)
                }

                if alignment == .leading {
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .opacity(isHovering && !isActive ? 0.7 : 1.0)
    }
}

// MARK: - List Row

struct FileListRow: View {
    let node: FileNode
    let parentTotalSize: Int64
    let isSelected: Bool
    let isActivelyScanning: Bool  // This folder is currently being scanned
    let onSelect: () -> Void
    let onNavigate: () -> Void
    var onRefresh: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    @State private var isRefreshHovering = false
    @State private var scanPulse = false

    private var sizePercentage: CGFloat {
        guard parentTotalSize > 0 else { return 0 }
        return CGFloat(node.size) / CGFloat(parentTotalSize)
    }

    private var isScanning: Bool {
        if case .scanning = node.scanStatus { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Size bar background
            GeometryReader { geometry in
                Rectangle()
                    .fill(FileTypeColors.color(for: node.fileType, scheme: colorScheme).opacity(0.12))
                    .frame(width: geometry.size.width * sizePercentage)
            }

            // Row content
            HStack(spacing: 0) {
                // Icon + Name
                HStack(spacing: 10) {
                    FileIcon(node: node)
                        .frame(width: 18, height: 18)

                    Text(node.name)
                        .font(.system(size: 13, weight: .regular))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Refresh button for folders - always reserve space to prevent layout shift
                if node.isDirectory {
                    RefreshButton(
                        isScanning: isScanning,
                        isHovering: $isRefreshHovering,
                        action: { onRefresh?() }
                    )
                    .padding(.trailing, 8)
                    .opacity(isHovering || isScanning ? 1 : 0)  // Hide but keep space
                }

                // Size
                Text(formatBytes(node.size))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)

                // Item count
                Text(node.isDirectory ? "\(node.itemCount)" : "-")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 60, alignment: .trailing)

                // Modified date
                Text(formatDate(node.modifiedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(rowBackground)
        .contentShape(Rectangle())
        .scanStatus(node.scanStatus)
        .onTapGesture(count: 2) {
            onNavigate()
        }
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if isActivelyScanning {
                // Pulsing green background for actively scanning folder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(scanPulse ? 0.15 : 0.08))
                    .padding(.horizontal, 4)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: scanPulse)
                    .onAppear { scanPulse = true }
                    .onDisappear { scanPulse = false }
            } else if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
                    .padding(.horizontal, 4)
            } else if isHovering {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .padding(.horizontal, 4)
            } else {
                Color.clear
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Refresh Button

struct RefreshButton: View {
    let isScanning: Bool
    @Binding var isHovering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovering ? .primary : .secondary)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(isScanning)
        .help(isScanning ? "Scanning..." : "Rescan folder")
    }
}

// MARK: - File Icon

struct FileIcon: View {
    let node: FileNode
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .help(symlinkTooltip)
    }

    private var iconName: String {
        if node.isSymlink {
            return "link"
        }
        if node.isDirectory {
            return "folder.fill"
        }

        switch node.fileType {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "doc.zipper"
        case .application: return "app"
        case .document: return "doc.text"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if node.isSymlink {
            return .purple.opacity(0.8)
        }
        if node.isDirectory {
            return FileTypeColors.color(for: .other, scheme: colorScheme).opacity(0.8)
        }
        return FileTypeColors.color(for: node.fileType, scheme: colorScheme)
    }

    private var symlinkTooltip: String {
        if node.isSymlink {
            if let target = node.symlinkTarget {
                return "Symlink to: \(target)"
            }
            return "Symlink (size not counted in parent total)"
        }
        return ""
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    let nodes = [
        FileNode(path: URL(fileURLWithPath: "/test/Large Folder"), name: "Large Folder", size: 5_000_000_000, isDirectory: true),
        FileNode(path: URL(fileURLWithPath: "/test/video.mp4"), name: "video.mp4", size: 1_500_000_000, isDirectory: false),
        FileNode(path: URL(fileURLWithPath: "/test/photo.jpg"), name: "photo.jpg", size: 50_000_000, isDirectory: false),
    ]

    return FileListView(appState: state, nodes: nodes)
        .frame(width: 400, height: 300)
}
