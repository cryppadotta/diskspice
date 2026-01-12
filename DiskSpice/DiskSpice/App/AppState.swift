import SwiftUI

// MARK: - Scan Progress

struct ScanProgress: Sendable {
    var currentPath: String
    var filesScanned: Int
    var bytesScanned: Int64
    var startTime: Date

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var filesPerSecond: Double {
        guard elapsedTime > 0 else { return 0 }
        return Double(filesScanned) / elapsedTime
    }
}

// MARK: - Sort Types

enum SortField: String, CaseIterable {
    case size = "Size"
    case name = "Name"
    case modified = "Modified"
    case itemCount = "Items"
}

enum SortOrder {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

// MARK: - App State

@MainActor
@Observable
class AppState {
    var volumes: [VolumeInfo] = []
    var navigationState: NavigationState
    var selectedNode: FileNode?
    var isScanning = false
    var scanningPath: URL?
    var searchQuery = ""

    // Sorting
    var sortField: SortField = .size
    var sortOrder: SortOrder = .descending

    // Scan progress
    var scanProgress: ScanProgress?

    // Scanner coordinator (set after initialization)
    var coordinator: ScanCoordinator?

    // Prioritized scan queue
    let scanQueue = ScanQueue()

    // File tree cache - maps path to children
    private var fileTree: [URL: [FileNode]] = [:]

    init() {
        // Default to root
        self.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/"))

        // Set up scan queue callback
        scanQueue.onDirectoryScanned = { [weak self] path, children in
            Task { @MainActor in
                self?.fileTree[path] = children
                debugLog("ScanQueue completed: \(path.path) with \(children.count) children", category: "SCAN")
            }
        }
    }

    /// Check if a path needs scanning
    func needsScan(at path: URL) -> Bool {
        return scanQueue.needsScan(path: path)
    }

    // MARK: - Computed Properties for Scan Status

    /// The path currently being scanned (if any)
    var currentlyScanningPath: URL? {
        scanQueue.currentTask?.path
    }

    /// Check if a specific path is currently being scanned
    func isCurrentlyScanning(path: URL) -> Bool {
        scanQueue.currentTask?.path == path
    }

    // MARK: - Computed Properties

    var currentVolume: VolumeInfo? {
        volumes.first { vol in
            navigationState.currentPath.path.hasPrefix(vol.path.path)
        }
    }

    var currentChildren: [FileNode] {
        let children = fileTree[navigationState.currentPath] ?? []
        if searchQuery.isEmpty {
            return children
        }
        return children.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
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

    /// Navigate to a path and prioritize scanning it
    func navigateTo(_ path: URL) {
        debugLog("navigateTo: \(path.path), needsScan=\(needsScan(at: path))", category: "NAV")

        withAnimation(.easeInOut(duration: 0.2)) {
            navigationState.navigateTo(path)
            selectedNode = nil
        }

        // Prioritize this path in the scan queue
        // This will scan it immediately if not already scanned,
        // and queue its children for scanning next
        Task { @MainActor in
            scanQueue.prioritize(path: path)
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
        debugLog("navigateToSelected called, selectedNode=\(selectedNode?.name ?? "nil")", category: "NAV")
        guard let node = selectedNode, node.isDirectory else {
            debugLog("navigateToSelected: no valid selection", category: "NAV")
            return
        }
        navigateTo(node.path)
    }

    // MARK: - Sorting

    func toggleSort(for field: SortField) {
        if sortField == field {
            sortOrder.toggle()
        } else {
            sortField = field
            // Default order: size/itemCount descending, name/date ascending
            sortOrder = (field == .size || field == .itemCount) ? .descending : .ascending
        }
    }

    func sortedNodes(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { a, b in
            let comparison: Bool
            switch sortField {
            case .size:
                comparison = a.size < b.size
            case .name:
                comparison = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .modified:
                let dateA = a.modifiedDate ?? Date.distantPast
                let dateB = b.modifiedDate ?? Date.distantPast
                comparison = dateA < dateB
            case .itemCount:
                comparison = a.itemCount < b.itemCount
            }
            return sortOrder == .ascending ? comparison : !comparison
        }
    }

    // MARK: - File Operations

    func deleteSelectedNode() {
        guard let node = selectedNode else { return }

        // Check if confirmation is needed
        if FileOperations.requiresConfirmation(node) {
            guard FileOperations.confirmDeletion(of: node) else { return }
        }

        do {
            try FileOperations.moveToTrash(at: node.path)

            // Remove from file tree
            let parentPath = node.path.deletingLastPathComponent()
            if var children = fileTree[parentPath] {
                children.removeAll { $0.id == node.id }
                fileTree[parentPath] = children
            }

            // Clear selection
            selectedNode = nil

        } catch {
            print("Failed to delete: \(error.localizedDescription)")
        }
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
