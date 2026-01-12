# 015: Wire Up Navigation State Management

## Dependencies
- 003 (core data models)
- 013 (breadcrumb navigation)
- 014 (basic list view)

## Task
Connect all navigation components so that clicking breadcrumbs, back/up buttons, and list items properly updates the app state and displays the correct content.

## Spec Reference
See SPEC.md > Navigation: back button, breadcrumbs, keyboard shortcuts
See SPEC.md > Window Layout: selection syncs between views

## Implementation Details

### Update AppState.swift

```swift
import SwiftUI

@Observable
class AppState {
    var volumes: [VolumeInfo] = []
    var navigationState: NavigationState
    var selectedNode: FileNode?
    var isScanning = false
    var searchQuery = ""

    // File tree cache - maps path to children
    private var fileTree: [URL: [FileNode]] = [:]

    init() {
        self.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/"))
    }

    // MARK: - Computed Properties

    var currentVolume: VolumeInfo? {
        volumes.first { vol in
            navigationState.currentPath.path.hasPrefix(vol.path.path)
        }
    }

    var currentChildren: [FileNode] {
        fileTree[navigationState.currentPath] ?? []
    }

    var totalUsedSpace: Int64 {
        volumes.reduce(0) { $0 + $1.usedSize }
    }

    var totalFreeSpace: Int64 {
        volumes.reduce(0) { $0 + $1.freeSize }
    }

    var totalSpace: Int64 {
        volumes.reduce(0) { $0 + $1.totalSize }
    }

    // MARK: - Navigation

    func navigateTo(_ path: URL) {
        withAnimation(.easeInOut(duration: 0.2)) {
            navigationState.navigateTo(path)
            selectedNode = nil
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = navigationState.goBack()
            selectedNode = nil
        }
    }

    func goUp() {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = navigationState.goUp()
            selectedNode = nil
        }
    }

    func selectNode(_ node: FileNode) {
        selectedNode = node
    }

    func navigateToSelected() {
        guard let node = selectedNode, node.isDirectory else { return }
        navigateTo(node.path)
    }

    // MARK: - File Tree Management

    func updateChildren(at path: URL, children: [FileNode]) {
        fileTree[path] = children
    }

    func getChildren(at path: URL) -> [FileNode] {
        return fileTree[path] ?? []
    }

    func clearTree() {
        fileTree.removeAll()
    }
}
```

### Update ContentView.swift with keyboard shortcuts

```swift
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var splitRatio: CGFloat = 0.55

    var body: some View {
        VStack(spacing: 0) {
            DiskSummaryBar(appState: appState)
            BreadcrumbBar(appState: appState)

            SplitView(splitRatio: $splitRatio) {
                TreemapPlaceholder()
            } right: {
                FileListView(
                    appState: appState,
                    nodes: appState.currentChildren
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .focusable()
        .onKeyPress(.leftArrow, modifiers: .command) {
            appState.goBack()
            return .handled
        }
        .onKeyPress(.upArrow, modifiers: .command) {
            appState.goUp()
            return .handled
        }
        .onKeyPress(.escape) {
            appState.goBack()
            return .handled
        }
        .onKeyPress(.return) {
            appState.navigateToSelected()
            return .handled
        }
        .onAppear {
            loadMockData()
        }
    }

    private func loadMockData() {
        // Temporary mock data for testing navigation
        let mockVolume = VolumeInfo(
            path: URL(fileURLWithPath: "/"),
            name: "Macintosh HD",
            totalSize: 500_000_000_000,
            usedSize: 350_000_000_000
        )
        appState.volumes = [mockVolume]

        let mockChildren: [FileNode] = [
            FileNode(path: URL(fileURLWithPath: "/Users"), name: "Users", size: 150_000_000_000, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/Applications"), name: "Applications", size: 50_000_000_000, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/Library"), name: "Library", size: 30_000_000_000, isDirectory: true),
            FileNode(path: URL(fileURLWithPath: "/System"), name: "System", size: 20_000_000_000, isDirectory: true),
        ]

        appState.updateChildren(at: URL(fileURLWithPath: "/"), children: mockChildren)
    }
}
```

### Update FileListView to use AppState navigation

```swift
// In FileListRow, update onNavigate:
.onTapGesture(count: 2) {
    if node.isDirectory {
        appState.navigateTo(node.path)
    }
}
```

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Add navigation methods, file tree cache
- `DiskSpice/Views/ContentView.swift` - Add keyboard shortcuts, wire up state
- `DiskSpice/Views/List/FileListView.swift` - Use AppState navigation methods

## Acceptance Criteria
- [ ] Clicking breadcrumb navigates to that path
- [ ] Back button (and Cmd+[) goes to previous location
- [ ] Up button (and Cmd+Up) goes to parent folder
- [ ] Escape key goes back
- [ ] Double-clicking folder in list navigates into it
- [ ] Enter key navigates into selected folder
- [ ] Selection clears when navigating
- [ ] List updates to show children of current path
- [ ] Navigation is animated smoothly
- [ ] Mock data loads on app start for testing

## Completion Promise
`<promise>TICKET_015_COMPLETE</promise>`
