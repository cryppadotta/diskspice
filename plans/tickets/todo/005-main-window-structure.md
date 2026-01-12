# 005: Create Main Window Structure

## Dependencies
- 002 (project structure)
- 003 (core data models)

## Task
Set up the main application window with the basic layout shell: summary bar at top, split view below with treemap placeholder on left and list placeholder on right.

## Spec Reference
See SPEC.md > Window Layout section.

## Implementation Details

### Update AppState.swift
Expand AppState to hold the main app data:

```swift
import SwiftUI

@Observable
class AppState {
    var volumes: [VolumeInfo] = []
    var navigationState: NavigationState
    var selectedNode: FileNode?
    var isScanning = false
    var searchQuery = ""

    init() {
        // Default to root
        self.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/"))
    }

    var currentVolume: VolumeInfo? {
        volumes.first { vol in
            navigationState.currentPath.path.hasPrefix(vol.path.path)
        }
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
}
```

### ContentView.swift
Main layout with summary bar and split view:

```swift
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var splitPosition: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar
            DiskSummaryBar(appState: appState)

            // Navigation bar (breadcrumbs)
            NavigationBar(appState: appState)

            // Main split view
            HSplitView {
                // Treemap (left)
                TreemapPlaceholder()
                    .frame(minWidth: 300)

                // List (right)
                ListPlaceholder()
                    .frame(minWidth: 250)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Placeholder Views

struct DiskSummaryBar: View {
    let appState: AppState

    var body: some View {
        HStack {
            Text("Disk Summary")
                .font(.headline)
            Spacer()
            Text("Used: \(formatBytes(appState.totalUsedSpace)) / \(formatBytes(appState.totalSpace))")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct NavigationBar: View {
    let appState: AppState

    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
            }
            .disabled(!appState.navigationState.canGoBack)

            // Breadcrumbs placeholder
            Text(appState.navigationState.currentPath.path)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Search field placeholder
            TextField("Search", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar.opacity(0.5))
    }
}

struct TreemapPlaceholder: View {
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Text("Treemap View")
                .foregroundStyle(.secondary)
        }
    }
}

struct ListPlaceholder: View {
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Text("List View")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
```

### Update DiskSpiceApp.swift
Configure the window:

```swift
import SwiftUI

@main
struct DiskSpiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
```

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Update with navigation, volumes
- `DiskSpice/Views/ContentView.swift` - Main layout
- `DiskSpice/App/DiskSpiceApp.swift` - Window configuration

## Acceptance Criteria
- [ ] App window opens at 1200x800 default size
- [ ] Summary bar visible at top showing placeholder disk info
- [ ] Navigation bar below summary with back button and path
- [ ] Split view with resizable divider between treemap and list areas
- [ ] Placeholder text visible in both treemap and list areas
- [ ] Minimum window size of 800x600
- [ ] App builds and runs without errors

## Completion Promise
`<promise>TICKET_005_COMPLETE</promise>`
