# 003: Create Core Data Models

## Dependencies
- 002 (project structure)

## Task
Create the foundational data models for representing the file system tree, volumes, and scan state.

## Spec Reference
See SPEC.md > Scanning Engine, Caching & Persistence, UI sections.

## Implementation Details

### FileNode.swift
The core model representing a file or folder in the tree:

```swift
import Foundation

enum FileType: String, Codable, CaseIterable {
    case video, audio, image
    case code, archive, application
    case system, cache, document
    case other

    var color: String {
        switch self {
        case .video: return "blue"
        case .audio: return "purple"
        case .image: return "green"
        case .code: return "orange"
        case .archive: return "brown"
        case .application: return "red"
        case .system: return "gray"
        case .cache: return "yellow"
        case .document: return "teal"
        case .other: return "secondary"
        }
    }
}

enum ScanStatus: Codable {
    case stale
    case scanning
    case current
    case error(String)
}

struct FileNode: Identifiable, Codable {
    let id: UUID
    let path: URL
    let name: String
    var size: Int64
    var itemCount: Int
    var modifiedDate: Date?
    var isDirectory: Bool
    var isSymlink: Bool
    var children: [FileNode]?
    var fileType: FileType
    var scanStatus: ScanStatus
    var lastScanned: Date?

    init(path: URL, name: String, size: Int64 = 0, isDirectory: Bool = false) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.size = size
        self.itemCount = 0
        self.modifiedDate = nil
        self.isDirectory = isDirectory
        self.isSymlink = false
        self.children = isDirectory ? [] : nil
        self.fileType = .other
        self.scanStatus = .stale
        self.lastScanned = nil
    }
}
```

### VolumeInfo.swift
Model for mounted volumes:

```swift
import Foundation

struct VolumeInfo: Identifiable, Codable {
    let id: UUID
    let path: URL
    let name: String
    var totalSize: Int64
    var usedSize: Int64
    var freeSize: Int64
    var isExternal: Bool
    var rootNode: FileNode?

    var usedPercentage: Double {
        guard totalSize > 0 else { return 0 }
        return Double(usedSize) / Double(totalSize)
    }

    init(path: URL, name: String, totalSize: Int64, usedSize: Int64, isExternal: Bool = false) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.totalSize = totalSize
        self.usedSize = usedSize
        self.freeSize = totalSize - usedSize
        self.isExternal = isExternal
        self.rootNode = nil
    }
}
```

### NavigationState.swift
Model for tracking navigation history:

```swift
import Foundation

struct NavigationState {
    var currentPath: URL
    var history: [URL] = []
    var historyIndex: Int = -1

    mutating func navigateTo(_ path: URL) {
        // Truncate forward history if we navigated back then went somewhere new
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(currentPath)
        historyIndex = history.count - 1
        currentPath = path
    }

    mutating func goBack() -> URL? {
        guard historyIndex >= 0 else { return nil }
        let previousPath = history[historyIndex]
        historyIndex -= 1
        let temp = currentPath
        currentPath = previousPath
        return temp
    }

    mutating func goUp() -> URL? {
        let parent = currentPath.deletingLastPathComponent()
        guard parent != currentPath else { return nil }
        navigateTo(parent)
        return parent
    }

    var canGoBack: Bool {
        historyIndex >= 0
    }

    var breadcrumbs: [URL] {
        var crumbs: [URL] = []
        var path = currentPath
        while path.path != "/" {
            crumbs.insert(path, at: 0)
            path = path.deletingLastPathComponent()
        }
        crumbs.insert(URL(fileURLWithPath: "/"), at: 0)
        return crumbs
    }
}
```

## Files to Create/Modify
- `DiskSpice/Models/FileNode.swift` - New file
- `DiskSpice/Models/VolumeInfo.swift` - New file
- `DiskSpice/Models/NavigationState.swift` - New file

## Acceptance Criteria
- [ ] All three model files created in Models/ folder
- [ ] FileNode has all required properties (id, path, name, size, children, fileType, scanStatus)
- [ ] VolumeInfo can represent a mounted volume with size info
- [ ] NavigationState supports back, up, and breadcrumb navigation
- [ ] All models conform to Codable for persistence
- [ ] Project builds without errors

## Completion Promise
`<promise>TICKET_003_COMPLETE</promise>`
