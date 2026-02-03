import Foundation

@MainActor
class ScanCoordinator: ScannerDelegate {
    let scanner: any Scanner
    let appState: AppState

    private var pendingUpdates: [URL: PendingUpdates] = [:]
    private var updateDebounceTask: Task<Void, Never>?
    private var focusedScanPath: URL?

    init(scanner: any Scanner, appState: AppState) {
        self.scanner = scanner
        self.appState = appState

        // Set delegate using the stored scanner reference
        self.scanner.delegate = self
    }

    // MARK: - Public Interface

    func startScan(at path: URL) async {
        resetPendingUpdates()
        appState.isScanning = true
        appState.clearTree()
        await scanner.startScan(at: path)
    }

    func startFocusedScan(at path: URL) async {
        if scanner.isScanning {
            if focusedScanPath == path {
                return
            }
            scanner.cancelScan()
        }
        resetPendingUpdates()
        focusedScanPath = path
        appState.isScanning = true
        await scanner.startScan(at: path)
    }

    func refreshFolder(at path: URL) async {
        await scanner.refreshFolder(at: path)
    }

    func cancelScan() {
        scanner.cancelScan()
        resetPendingUpdates()
        appState.isScanning = false
    }

    // MARK: - ScannerDelegate

    nonisolated func scanner(_ scanner: any Scanner, didUpdateNode node: FileNode, at path: URL) {
        Task { @MainActor in
            self.handleNodeUpdate(node, at: path)
        }
    }

    nonisolated func scanner(_ scanner: any Scanner, didCompleteFolder path: URL) {
        Task { @MainActor in
            self.handleFolderComplete(path)
        }
    }

    nonisolated func scanner(_ scanner: any Scanner, didFailAt path: URL, error: Error) {
        Task { @MainActor in
            self.handleError(at: path, error: error)
        }
    }

    nonisolated func scannerDidComplete(_ scanner: any Scanner) {
        Task { @MainActor in
            self.handleScanComplete()
        }
    }

    // MARK: - Private Handlers

    private func handleNodeUpdate(_ node: FileNode, at parentPath: URL) {
        // Accumulate updates for batching
        var bucket = pendingUpdates[parentPath] ?? PendingUpdates()
        bucket.add(node)
        pendingUpdates[parentPath] = bucket

        // Debounce updates for performance
        scheduleFlush()
    }

    private func scheduleFlush() {
        updateDebounceTask?.cancel()
        updateDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            flushPendingUpdates()
        }
    }

    private func flushPendingUpdates() {
        for (path, bucket) in pendingUpdates {
            let newNodes = bucket.orderedNodes
            var existingChildren = appState.getChildren(at: path)
            var indexByPath: [URL: Int] = [:]

            for (index, child) in existingChildren.enumerated() {
                indexByPath[child.path] = index
            }

            var appended: [FileNode] = []
            for node in newNodes {
                if let index = indexByPath[node.path] {
                    existingChildren[index] = node
                } else {
                    appended.append(node)
                    indexByPath[node.path] = existingChildren.count + appended.count - 1
                }
            }

            if !appended.isEmpty {
                existingChildren.append(contentsOf: appended)
            }

            appState.updateChildren(at: path, children: existingChildren)
        }
        pendingUpdates.removeAll()
    }

    private func handleFolderComplete(_ path: URL) {
        // Flush any pending updates for this folder
        flushPendingUpdates()

        // Mark folder as complete (current status)
        var children = appState.getChildren(at: path)
        for i in children.indices {
            children[i].scanStatus = .current
            children[i].lastScanned = Date()
        }
        appState.updateChildren(at: path, children: children)
    }

    private func handleError(at path: URL, error: Error) {
        // Mark nodes at this path as having errors
        var children = appState.getChildren(at: path)
        for i in children.indices {
            children[i].scanStatus = .error(error.localizedDescription)
        }
        appState.updateChildren(at: path, children: children)

        debugError("Scan error at \(path.path)", error: error)
    }

    private func handleScanComplete() {
        flushPendingUpdates()
        appState.isScanning = false
        focusedScanPath = nil
    }

    private func resetPendingUpdates() {
        updateDebounceTask?.cancel()
        updateDebounceTask = nil
        pendingUpdates.removeAll()
    }
}

private struct PendingUpdates {
    private var nodesByPath: [URL: FileNode] = [:]
    private var order: [URL] = []

    mutating func add(_ node: FileNode) {
        if nodesByPath[node.path] == nil {
            order.append(node.path)
        }
        nodesByPath[node.path] = node
    }

    var orderedNodes: [FileNode] {
        order.compactMap { nodesByPath[$0] }
    }
}
