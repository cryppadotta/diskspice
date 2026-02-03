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
    private var pendingDirectoryUpdates: [URL: PendingDirectoryUpdate] = [:]
    private var coalesceTask: Task<Void, Never>?
    private var focusedScanTask: Task<Void, Never>?
    private let coalesceInterval: TimeInterval = 0.15

    init() {
        // Default to root
        self.navigationState = NavigationState(currentPath: URL(fileURLWithPath: "/"))

        // Set up scan queue callback
        scanQueue.onDirectoryScanned = { [weak self] path, children, isComplete in
            Task { @MainActor in
                self?.enqueueDirectoryUpdate(path: path, children: children, isComplete: isComplete)
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
            pathHasPrefix(navigationState.currentPath, prefix: vol.path)
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
        if let volume = currentVolume {
            return volume.usedSize
        }
        return volumes.reduce(0) { $0 + $1.usedSize }
    }

    var totalFreeSpace: Int64 {
        if let volume = currentVolume {
            return volume.freeSize
        }
        return volumes.reduce(0) { $0 + $1.freeSize }
    }

    var totalSpace: Int64 {
        if let volume = currentVolume {
            return volume.totalSize
        }
        return volumes.reduce(0) { $0 + $1.totalSize }
    }

    var isScanningVolumeUsage: Bool {
        guard let volume = currentVolume else {
            return scanQueue.isScanning
        }
        guard scanQueue.isScanning else { return false }
        return scanQueue.currentTask?.path == volume.path
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
            scanQueue.prioritize(path: path, force: false)
            requestFocusedScan(for: path)
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = navigationState.goBack()
            selectedNode = nil
        }
        let path = navigationState.currentPath
        Task { @MainActor in
            scanQueue.prioritize(path: path, force: false)
            requestFocusedScan(for: path)
        }
    }

    func goUp() {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = navigationState.goUp()
            selectedNode = nil
        }
        let path = navigationState.currentPath
        Task { @MainActor in
            scanQueue.prioritize(path: path, force: false)
            requestFocusedScan(for: path)
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
                let aCalculating = isCalculatingSize(a)
                let bCalculating = isCalculatingSize(b)
                if aCalculating != bCalculating {
                    return !aCalculating
                }
                if aCalculating && bCalculating {
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
                if a.size == b.size {
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
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

        let parentPath = node.path.deletingLastPathComponent()
        let nodePath = node.path

        // Optimistically remove from UI to avoid blocking the main thread.
        if var children = fileTree[parentPath] {
            children.removeAll { $0.id == node.id }
            fileTree[parentPath] = children
            updateParentNode(for: parentPath, children: children)
        }

        if selectedNode?.id == node.id {
            selectedNode = nil
        }

        sortedCache = nil

        Task { [weak self] in
            do {
                _ = try await FileOperations.moveToTrashAsync(at: nodePath)
            } catch {
                debugError("Failed to move to Trash: \(nodePath.path)", error: error)
                await MainActor.run {
                    self?.scanQueue.prioritize(path: parentPath, force: true)
                }
            }
        }
    }

    // MARK: - File Tree Management

    func updateChildren(at path: URL, children: [FileNode]) {
        fileTree[path] = children
        if path == navigationState.currentPath {
            sortedCache = nil
        }
    }

    func clearCache() {
        cacheSaveTasks.values.forEach { $0.cancel() }
        cacheSaveTasks.removeAll()
        Task {
            do {
                try await CacheManager.shared.clearAll()
            } catch {
                debugLog("Cache clear failed: \(error)", category: "CACHE")
            }
        }
    }

    func getChildren(at path: URL) -> [FileNode] {
        return fileTree[path] ?? []
    }

    func nodeForPath(_ path: URL) -> FileNode? {
        let parentPath = path.deletingLastPathComponent()
        guard let children = fileTree[parentPath] else { return nil }
        return children.first(where: { $0.path == path })
    }

    func clearTree() {
        fileTree.removeAll()
        sortedCache = nil
        coalesceTask?.cancel()
        coalesceTask = nil
        pendingDirectoryUpdates.removeAll()
    }
}

private extension AppState {
    func isCalculatingSize(_ node: FileNode) -> Bool {
        guard node.isDirectory, node.size == 0 else { return false }
        if node.lastScanned == nil {
            return true
        }
        switch node.scanStatus {
        case .stale, .scanning:
            return true
        case .current, .error:
            return false
        }
    }

    func requestFocusedScan(for path: URL) {
        guard coordinator != nil else { return }
        guard !isDirectoryComplete(path) else { return }
        focusedScanTask?.cancel()
        focusedScanTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(120))
            guard self.navigationState.currentPath == path else { return }
            await self.coordinator?.startFocusedScan(at: path)
        }
    }

    func mergeChildren(existing: [FileNode], newChildren: [FileNode], isComplete: Bool) -> [FileNode] {
        guard !existing.isEmpty else { return newChildren }
        var existingByPath: [URL: FileNode] = [:]
        for node in existing {
            existingByPath[node.path] = node
        }

        let mergedNew = newChildren.map { child in
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

            if child.isDirectory && !newIsCurrent {
                var merged = child
                if existingNode.size > 0 || existingNode.itemCount > 0 {
                    merged.size = max(existingNode.size, child.size)
                    merged.itemCount = max(existingNode.itemCount, child.itemCount)
                    merged.scanStatus = existingNode.scanStatus
                    merged.lastScanned = existingNode.lastScanned
                }
                return merged
            }

            if child.lastScanned == nil, let existingScanned = existingNode.lastScanned {
                var merged = child
                merged.lastScanned = existingScanned
                return merged
            }

            return child
        }

        if isComplete {
            return mergedNew
        }

        var merged = mergedNew
        let newPaths = Set(newChildren.map { $0.path })
        for node in existing where !newPaths.contains(node.path) {
            merged.append(node)
        }
        return merged
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
        let treeForVolume = fileTree.filter { pathHasPrefix($0.key, prefix: volume.path) }
        do {
            try await CacheManager.shared.saveTree(treeForVolume, for: volume)
        } catch {
            debugLog("Cache save failed: \(error)", category: "CACHE")
        }
    }

    func volumeForPath(_ path: URL) -> VolumeInfo? {
        volumes.first { pathHasPrefix(path, prefix: $0.path) }
    }

    func updateParentNode(for path: URL, children: [FileNode], isComplete: Bool = true) {
        let parentPath = path.deletingLastPathComponent()
        var existingChildren = fileTree[parentPath] ?? []
        guard let index = existingChildren.firstIndex(where: { $0.path == path }) else { return }

        var node = existingChildren[index]
        node.size = children.reduce(0) { $0 + $1.effectiveSize }
        node.itemCount = children.count
        node.scanStatus = isComplete ? .current : .scanning
        node.lastScanned = isComplete ? Date() : node.lastScanned
        existingChildren[index] = node

        fileTree[parentPath] = existingChildren
        if parentPath == navigationState.currentPath {
            sortedCache = nil
            refreshSelectionIfNeeded(for: parentPath)
        }
        updateAncestorTotals(from: parentPath)
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
            refreshSelectionIfNeeded(for: parentPath)
        }
    }

    func updateAncestorTotals(from path: URL) {
        var currentPath = path
        while true {
            let parentPath = currentPath.deletingLastPathComponent()
            guard parentPath != currentPath else { break }
            guard var siblings = fileTree[parentPath],
                  let index = siblings.firstIndex(where: { $0.path == currentPath }),
                  let currentChildren = fileTree[currentPath]
            else { break }

            var node = siblings[index]
            node.size = currentChildren.reduce(0) { $0 + $1.effectiveSize }
            node.itemCount = currentChildren.count
            siblings[index] = node
            fileTree[parentPath] = siblings

            if parentPath == navigationState.currentPath {
                sortedCache = nil
                refreshSelectionIfNeeded(for: parentPath)
            }

            currentPath = parentPath
        }
    }

    func enqueueDirectoryUpdate(path: URL, children: [FileNode], isComplete: Bool) {
        let existing = pendingDirectoryUpdates[path]?.children ?? fileTree[path] ?? []
        let merged = mergeChildren(existing: existing, newChildren: children, isComplete: isComplete)
        let wasComplete = pendingDirectoryUpdates[path]?.isComplete ?? false
        pendingDirectoryUpdates[path] = PendingDirectoryUpdate(children: merged, isComplete: wasComplete || isComplete)
        debugLog(
            "enqueueDirectoryUpdate: \(path.path)",
            data: [
                "existing": existing.count,
                "incoming": children.count,
                "merged": merged.count,
                "complete": isComplete
            ],
            category: "SCAN"
        )
        scheduleCoalescedFlush()
    }

    func scheduleCoalescedFlush() {
        guard coalesceTask == nil else { return }
        coalesceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(self.coalesceInterval * 1000)))
            self.flushPendingDirectoryUpdates()
        }
    }

    func flushPendingDirectoryUpdates() {
        guard !pendingDirectoryUpdates.isEmpty else {
            coalesceTask = nil
            return
        }
        let updates = pendingDirectoryUpdates
        pendingDirectoryUpdates.removeAll()
        coalesceTask = nil

        for (path, update) in updates {
            fileTree[path] = update.children
            updateParentNode(for: path, children: update.children, isComplete: update.isComplete)
            if path == navigationState.currentPath {
                sortedCache = nil
                refreshSelectionIfNeeded(for: path)
            }
            debugLog("ScanQueue completed: \(path.path) with \(update.children.count) children", category: "SCAN")
            if update.isComplete {
                scheduleCacheSave(for: path)
            }
        }
    }

    func refreshSelectionIfNeeded(for path: URL) {
        guard path == navigationState.currentPath else { return }
        guard let selectedNode else { return }
        guard let updatedNode = fileTree[path]?.first(where: { $0.path == selectedNode.path }) else { return }
        self.selectedNode = updatedNode
    }

    func isDirectoryComplete(_ path: URL) -> Bool {
        if let children = fileTree[path] {
            return !children.contains { child in
                switch child.scanStatus {
                case .scanning, .stale:
                    return true
                case .current, .error:
                    return false
                }
            }
        }
        return !scanQueue.needsScan(path: path)
    }

    func pathHasPrefix(_ path: URL, prefix: URL) -> Bool {
        let pathComponents = path.standardizedFileURL.pathComponents
        let prefixComponents = prefix.standardizedFileURL.pathComponents
        guard prefixComponents.count <= pathComponents.count else { return false }
        return Array(pathComponents.prefix(prefixComponents.count)) == prefixComponents
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

private struct PendingDirectoryUpdate {
    let children: [FileNode]
    let isComplete: Bool
}
