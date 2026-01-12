# 022: Sync Selection Between Treemap and List

## Dependencies
- 014 (basic list view)
- 017 (canvas treemap renderer)
- 015 (navigation state management)

## Task
Ensure that selecting an item in the treemap highlights it in the list view, and vice versa.

## Spec Reference
See SPEC.md > Window Layout: "Selection syncs between both views (click in treemap highlights in list, vice versa)"

## Implementation Details

### Update AppState with selection binding

```swift
// In AppState.swift

@Observable
class AppState {
    // ... existing properties ...

    var selectedNodeId: UUID? = nil

    var selectedNode: FileNode? {
        get {
            guard let id = selectedNodeId else { return nil }
            return findNode(withId: id, in: currentChildren)
        }
        set {
            selectedNodeId = newValue?.id
        }
    }

    private func findNode(withId id: UUID, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let children = node.children,
               let found = findNode(withId: id, in: children) {
                return found
            }
        }
        return nil
    }

    func selectNode(_ node: FileNode?) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedNodeId = node?.id
        }
    }
}
```

### Update TreemapView to use shared selection

```swift
// In TreemapContainer.swift or TreemapView.swift

struct TreemapContainer: View {
    @Bindable var appState: AppState

    @State private var hoveredId: UUID? = nil
    // Remove local selectedId - use appState.selectedNodeId instead

    var body: some View {
        TreemapView(
            nodes: appState.currentChildren,
            selectedId: appState.selectedNodeId,  // Bind to AppState
            hoveredId: $hoveredId,
            onSelect: { node in
                appState.selectNode(node)
            },
            onNavigate: { node in
                appState.navigateTo(node.path)
            }
        )
    }
}
```

### Update FileListView to use shared selection

```swift
// In FileListView.swift

struct FileListView: View {
    @Bindable var appState: AppState
    let nodes: [FileNode]

    var body: some View {
        VStack(spacing: 0) {
            FileListHeader()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedNodes) { node in
                            FileListRow(
                                node: node,
                                isSelected: appState.selectedNodeId == node.id,
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
                .onChange(of: appState.selectedNodeId) { _, newId in
                    // Scroll to selected item when selection changes
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

    private var sortedNodes: [FileNode] {
        nodes.sorted { $0.size > $1.size }
    }
}
```

### Update FileListRow selection styling

```swift
struct FileListRow: View {
    let node: FileNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onNavigate: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // ... row content ...
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
                    .padding(.horizontal, 4)
            } else if isHovering {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onNavigate()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}
```

### Keyboard navigation support

```swift
// In ContentView.swift

.onKeyPress(.downArrow) {
    selectNextItem()
    return .handled
}
.onKeyPress(.upArrow) {
    selectPreviousItem()
    return .handled
}

private func selectNextItem() {
    let nodes = appState.currentChildren.sorted { $0.size > $1.size }
    if let currentId = appState.selectedNodeId,
       let currentIndex = nodes.firstIndex(where: { $0.id == currentId }),
       currentIndex < nodes.count - 1 {
        appState.selectNode(nodes[currentIndex + 1])
    } else if !nodes.isEmpty {
        appState.selectNode(nodes[0])
    }
}

private func selectPreviousItem() {
    let nodes = appState.currentChildren.sorted { $0.size > $1.size }
    if let currentId = appState.selectedNodeId,
       let currentIndex = nodes.firstIndex(where: { $0.id == currentId }),
       currentIndex > 0 {
        appState.selectNode(nodes[currentIndex - 1])
    }
}
```

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Add shared selection state
- `DiskSpice/Views/Treemap/TreemapContainer.swift` - Use shared selection
- `DiskSpice/Views/List/FileListView.swift` - Use shared selection, auto-scroll
- `DiskSpice/Views/List/FileListRow.swift` - Enhanced selection styling
- `DiskSpice/Views/ContentView.swift` - Keyboard navigation

## Acceptance Criteria
- [ ] Clicking item in treemap highlights same item in list
- [ ] Clicking item in list highlights same item in treemap
- [ ] Selection is animated smoothly
- [ ] List auto-scrolls to show selected item
- [ ] Selected item has consistent styling in both views
- [ ] Arrow keys navigate through list items
- [ ] Enter key on selected folder navigates into it
- [ ] Selection clears when navigating to new folder
- [ ] Hover states don't interfere with selection state

## Completion Promise
`<promise>TICKET_022_COMPLETE</promise>`
