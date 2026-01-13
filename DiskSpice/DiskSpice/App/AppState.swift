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
    private var sortedCache: (key: SortedNodesKey, nodes: [FileNode])?
    private var cacheSaveTasks: [String: Task<Void, Never>] = [:]

    init() {
        // Default to root
        self.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/"))

        // Set up scan queue callback
        scanQueue.onDirectoryScanned = { [weak self] path, children in
            Task { @MainActor in
                let merged = self?.mergeChildren(existing: self?.fileTree[path] ?? [], newChildren: children) ?? children
                self?.fileTree[path] = merged
                self?.updateParentNode(for: path, children: merged)
                debugLog("ScanQueue completed: \(path.path) with \(children.count) children", category: "SCAN")
                self?.scheduleCacheSave(for: path)
            }
        }
        scanQueue.onDirectoryProgress = { [weak self] path, filesScanned, bytesScanned in
            Task { @MainActor in
                self?.updateProgressNode(for: path, filesScanned: filesScanned, bytesScanned: bytesScanned)
            }
        }
    }

    func applyCachedTree(_ tree: [URL: [FileNode]]) {
        for (path, children) in tree {
            let staleChildren = children.map { node -> FileNode in
                var updated = node
                updated.scanStatus = .stale
                return updated
            }
            fileTree[path] = staleChildren
        }
        sortedCache = nil
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
            scanQueue.prioritize(path: path, force: true)
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
        sortedCache = nil
    }

    func sortedNodes(for path: URL, nodes: [FileNode]) -> [FileNode] {
        let key = SortedNodesKey(
            path: path,
            sortField: sortField,
            sortOrder: sortOrder,
            signature: nodesSignature(nodes)
        )

        if let cached = sortedCache, cached.key == key {
            return cached.nodes
        }

        let sorted = nodes.sorted { a, b in
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

        sortedCache = (key: key, nodes: sorted)
        return sorted
    }

    // MARK: - File Operations

    func deleteSelectedNode() {
        guard let node = selectedNode else { return }
        deleteNode(node)
    }

    func deleteNode(_ node: FileNode) {
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
                updateParentNode(for: parentPath, children: children)
            }

            if selectedNode?.id == node.id {
                selectedNode = nil
            }

            sortedCache = nil
        } catch {
            print("Failed to delete: \(error.localizedDescription)")
        }
    }

    // MARK: - File Tree Management

    func updateChildren(at path: URL, children: [FileNode]) {
        fileTree[path] = children
        if path == navigationState.currentPath {
            sortedCache = nil
        }
    }

    func getChildren(at path: URL) -> [FileNode] {
        return fileTree[path] ?? []
    }

    func clearTree() {
        fileTree.removeAll()
        sortedCache = nil
    }
}

private extension AppState {
    func mergeChildren(existing: [FileNode], newChildren: [FileNode]) -> [FileNode] {
        guard !existing.isEmpty else { return newChildren }
        var existingByPath: [URL: FileNode] = [:]
        for node in existing {
            existingByPath[node.path] = node
        }

        return newChildren.map { child in
            guard let existingNode = existingByPath[child.path] else { return child }
            let existingIsCurrent: Bool
            if case .current = existingNode.scanStatus {
                existingIsCurrent = true
            } else {
                existingIsCurrent = false
            }

            let newIsCurrent: Bool
            if case .current = child.scanStatus {
                newIsCurrent = true
            } else {
                newIsCurrent = false
            }

            if existingIsCurrent && !newIsCurrent {
                return existingNode
            }

            if child.isDirectory && !newIsCurrent && (existingNode.size > 0 || existingNode.itemCount > 0) {
                var merged = child
                merged.size = existingNode.size
                merged.itemCount = existingNode.itemCount
                merged.scanStatus = existingNode.scanStatus
                merged.lastScanned = existingNode.lastScanned
                return merged
            }

            if child.lastScanned == nil, let existingScanned = existingNode.lastScanned {
                var merged = child
                merged.lastScanned = existingScanned
                return merged
            }

            return child
        }
    }

    func scheduleCacheSave(for path: URL) {
        guard let volume = volumeForPath(path) else { return }
        let key = volume.path.path
        cacheSaveTasks[key]?.cancel()
        cacheSaveTasks[key] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.saveCache(for: volume)
        }
    }

    func saveCache(for volume: VolumeInfo) async {
        let volumePath = volume.path.path
        let treeForVolume = fileTree.filter { $0.key.path.hasPrefix(volumePath) }
        do {
            try await CacheManager.shared.saveTree(treeForVolume, for: volume)
        } catch {
            debugLog("Cache save failed: \(error)", category: "CACHE")
        }
    }

    func volumeForPath(_ path: URL) -> VolumeInfo? {
        volumes.first { path.path.hasPrefix($0.path.path) }
    }

    func updateParentNode(for path: URL, children: [FileNode]) {
        let parentPath = path.deletingLastPathComponent()
        var existingChildren = fileTree[parentPath] ?? []
        guard let index = existingChildren.firstIndex(where: { $0.path == path }) else { return }

        var node = existingChildren[index]
        node.size = children.reduce(0) { $0 + $1.effectiveSize }
        node.itemCount = children.count
        node.scanStatus = .current
        node.lastScanned = Date()
        existingChildren[index] = node

        fileTree[parentPath] = existingChildren
        if parentPath == navigationState.currentPath {
            sortedCache = nil
        }
    }

    func updateProgressNode(for path: URL, filesScanned: Int, bytesScanned: Int64) {
        let parentPath = path.deletingLastPathComponent()
        var existingChildren = fileTree[parentPath] ?? []
        guard let index = existingChildren.firstIndex(where: { $0.path == path }) else { return }

        var node = existingChildren[index]
        node.size = bytesScanned
        node.itemCount = filesScanned
        node.scanStatus = .scanning
        existingChildren[index] = node

        fileTree[parentPath] = existingChildren
        if parentPath == navigationState.currentPath {
            sortedCache = nil
        }
    }
}

private struct SortedNodesKey: Equatable {
    let path: URL
    let sortField: SortField
    let sortOrder: SortOrder
    let signature: Int
}

private func nodesSignature(_ nodes: [FileNode]) -> Int {
    var hasher = Hasher()
    hasher.combine(nodes.count)
    for node in nodes {
        hasher.combine(node.path)
        hasher.combine(node.name)
        hasher.combine(node.size)
        hasher.combine(node.itemCount)
        hasher.combine(node.modifiedDate?.timeIntervalSince1970 ?? 0)
    }
    return hasher.finalize()
}
