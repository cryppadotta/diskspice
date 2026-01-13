import SwiftUI
import AppKit

struct FileListView: View {
    @Bindable var appState: AppState
    let nodes: [FileNode]

    @State private var frozenNodes: [FileNode] = []
    @State private var isListHovering = false
    @State private var freezeSorting = false
    @State private var moveToken = 0

    private let freezeInterval: TimeInterval = 0.7

    private var parentTotalSize: Int64 {
        // Exclude symlinks from total to avoid double-counting
        nodes.reduce(0) { $0 + $1.effectiveSize }
    }

    private var sortedNodes: [FileNode] {
        appState.sortedNodes(for: appState.navigationState.currentPath, nodes: nodes)
    }

    private var shouldFreezeSorting: Bool {
        isListHovering && freezeSorting
    }

    private var displayNodes: [FileNode] {
        if shouldFreezeSorting {
            return mergeFrozenOrder(frozenNodes, with: nodes)
        }
        return sortedNodes
    }

    var body: some View {
        GeometryReader { geometry in
            let headerHeight: CGFloat = 30
            VStack(spacing: 0) {
                // Header
                FileListHeader(
                    sortField: appState.sortField,
                    sortOrder: appState.sortOrder,
                    onSort: { field in appState.toggleSort(for: field) }
                )
                .frame(height: headerHeight, alignment: .center)

                // List with auto-scroll
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayNodes) { node in
                                FileListRow(
                                    node: node,
                                    parentTotalSize: parentTotalSize,
                                    isSelected: appState.selectedNode?.id == node.id,
                                    isActivelyScanning: appState.isCurrentlyScanning(path: node.path),
                                    onSelect: {
                                        if node.isDirectory {
                                            appState.navigateTo(node.path)
                                        } else {
                                            appState.selectNode(node)
                                        }
                                    },
                                    onDelete: {
                                        appState.deleteNode(node)
                                    }
                                )
                                .id(node.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(height: max(0, geometry.size.height - headerHeight), alignment: .top)
                    .background(
                        MouseTrackingView(
                            onMove: { handleMouseMove() },
                            onHoverChange: { hovering in
                                isListHovering = hovering
                                if !hovering {
                                    freezeSorting = false
                                }
                            }
                        )
                    )
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
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            frozenNodes = sortedNodes
        }
        .onChange(of: nodes) { _, _ in
            if !shouldFreezeSorting {
                frozenNodes = sortedNodes
            }
        }
        .onChange(of: appState.sortField) { _, _ in
            if !shouldFreezeSorting {
                frozenNodes = sortedNodes
            }
        }
        .onChange(of: appState.sortOrder) { _, _ in
            if !shouldFreezeSorting {
                frozenNodes = sortedNodes
            }
        }
        .onChange(of: appState.navigationState.currentPath) { _, _ in
            freezeSorting = false
            frozenNodes = sortedNodes
        }
        .onChange(of: freezeSorting) { _, newValue in
            if !newValue {
                frozenNodes = sortedNodes
            }
        }
    }

    private func handleMouseMove() {
        moveToken += 1
        let token = moveToken
        freezeSorting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + freezeInterval) {
            if moveToken == token {
                freezeSorting = false
            }
        }
    }

    private func mergeFrozenOrder(_ frozen: [FileNode], with current: [FileNode]) -> [FileNode] {
        guard !frozen.isEmpty else { return current }
        var byPath: [URL: FileNode] = [:]
        for node in current {
            byPath[node.path] = node
        }

        var merged: [FileNode] = []
        var seen: Set<URL> = []

        for node in frozen {
            if let updated = byPath[node.path] {
                merged.append(updated)
            } else {
                merged.append(node)
            }
            seen.insert(node.path)
        }

        let newNodes = current.filter { !seen.contains($0.path) }
        let appended = newNodes.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        merged.append(contentsOf: appended)
        return merged
    }
}

private struct MouseTrackingView: NSViewRepresentable {
    let onMove: () -> Void
    let onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMove = onMove
        view.onHoverChange = onHoverChange
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onMove = onMove
        nsView.onHoverChange = onHoverChange
    }
}

private final class TrackingView: NSView {
    var onMove: (() -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseEnteredAndExited,
            .mouseMoved,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    override func mouseMoved(with event: NSEvent) {
        onMove?()
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

            Color.clear
                .frame(width: 20)
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
    let onDelete: () -> Void
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
            Rectangle()
                .fill(FileTypeColors.color(for: node.fileType, scheme: colorScheme).opacity(0.12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: sizePercentage, y: 1, anchor: .leading)

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
                Text(sizeText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .trailing)

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

                TrashButton(action: {
                    playTrashSound()
                    onDelete()
                })
                .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(rowBackground)
        .contentShape(Rectangle())
        .scanStatus(node.scanStatus, showShimmer: false)
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Move to Trash", systemImage: "trash") {
                playTrashSound()
                onDelete()
            }
            Button("Open Enclosing Folder in Finder", systemImage: "folder") {
                FileOperations.revealInFinder(node.path)
            }
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

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private func formatBytes(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        return Self.dateFormatter.string(from: date)
    }

    private var sizeText: String {
        guard node.isDirectory else {
            return formatBytes(node.size)
        }

        if node.size > 0 {
            switch node.scanStatus {
            case .stale, .scanning:
                return "\(formatBytes(node.size))..."
            case .current, .error:
                return formatBytes(node.size)
            }
        }

        if node.lastScanned == nil {
            return "Calculating"
        }

        switch node.scanStatus {
        case .stale, .scanning:
            return "Calculating"
        case .current, .error:
            return formatBytes(node.size)
        }
    }

    private func playTrashSound() {
        NSSound(named: NSSound.Name("moveToTrash"))?.play()
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

// MARK: - Trash Button

struct TrashButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help("Move to Trash")
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

    FileListView(appState: state, nodes: nodes)
        .frame(width: 400, height: 300)
}
