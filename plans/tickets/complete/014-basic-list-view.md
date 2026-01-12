# 014: Create Basic List View

## Dependencies
- 003 (core data models)
- 005 (main window structure)

## Task
Build the list view panel showing files/folders sorted by size with basic row layout. This ticket covers structure; polish comes in Phase 5.

## Spec Reference
See SPEC.md > UI - List View (Right Panel): sorted by size, name/size/count/date

## Implementation Details

### FileListView.swift

```swift
import SwiftUI

struct FileListView: View {
    @Bindable var appState: AppState
    let nodes: [FileNode]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            FileListHeader()

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedNodes) { node in
                        FileListRow(
                            node: node,
                            isSelected: appState.selectedNode?.id == node.id,
                            onSelect: {
                                appState.selectedNode = node
                            },
                            onNavigate: {
                                if node.isDirectory {
                                    appState.navigationState.navigateTo(node.path)
                                }
                            }
                        )
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sortedNodes: [FileNode] {
        nodes.sorted { $0.size > $1.size }
    }
}

// MARK: - List Header

struct FileListHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Size")
                .frame(width: 80, alignment: .trailing)

            Text("Items")
                .frame(width: 60, alignment: .trailing)

            Text("Modified")
                .frame(width: 100, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
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

// MARK: - List Row

struct FileListRow: View {
    let node: FileNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onNavigate: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Icon + Name
            HStack(spacing: 8) {
                FileIcon(node: node)
                    .frame(width: 16, height: 16)

                Text(node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(formatBytes(node.size))
                .font(.system(size: 12, design: .monospaced))
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
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(rowBackground)
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onNavigate()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
        return .clear
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

// MARK: - File Icon

struct FileIcon: View {
    let node: FileNode

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
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
        if node.isDirectory {
            return .blue
        }
        return .secondary
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
```

## Files to Create/Modify
- `DiskSpice/Views/List/FileListView.swift` - New file
- `DiskSpice/Views/List/FileListRow.swift` - Can be in same file or separate
- `DiskSpice/Views/ContentView.swift` - Wire up FileListView

## Acceptance Criteria
- [ ] List displays files/folders sorted by size (largest first)
- [ ] Each row shows: icon, name, size, item count, modified date
- [ ] Folders have folder icon, files have type-appropriate icons
- [ ] Single click selects row
- [ ] Double click navigates into folder
- [ ] Selected row is highlighted
- [ ] Hover state on rows
- [ ] Header row with column labels
- [ ] Scrollable with LazyVStack for performance
- [ ] Size formatted nicely (KB, MB, GB)

## Completion Promise
`<promise>TICKET_014_COMPLETE</promise>`
