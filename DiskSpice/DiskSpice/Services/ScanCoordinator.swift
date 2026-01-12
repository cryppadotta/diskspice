import Foundation

@MainActor
class ScanCoordinator: ScannerDelegate {
    let scanner: any Scanner
    let appState: AppState

    private var pendingUpdates: [URL: [FileNode]] = [:]
    private var updateDebounceTask: Task<Void, Never>?

    init(scanner: any Scanner, appState: AppState) {
        self.scanner = scanner
        self.appState = appState

        // Set delegate using the stored scanner reference
        self.scanner.delegate = self
    }

    // MARK: - Public Interface

    func startScan(at path: URL) async {
        appState.isScanning = true
        appState.clearTree()
        await scanner.startScan(at: path)
    }

    func refreshFolder(at path: URL) async {
        await scanner.refreshFolder(at: path)
    }

    func cancelScan() {
        scanner.cancelScan()
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
        var children = pendingUpdates[parentPath] ?? []

        // Update or add the node
        if let index = children.firstIndex(where: { $0.path == node.path }) {
            children[index] = node
        } else {
            children.append(node)
        }
        pendingUpdates[parentPath] = children

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
        for (path, newNodes) in pendingUpdates {
            // Merge with existing children
            var existingChildren = appState.getChildren(at: path)

            for node in newNodes {
                if let index = existingChildren.firstIndex(where: { $0.path == node.path }) {
                    existingChildren[index] = node
                } else {
                    existingChildren.append(node)
                }
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

        print("Scan error at \(path.path): \(error.localizedDescription)")
    }

    private func handleScanComplete() {
        flushPendingUpdates()
        appState.isScanning = false
    }
}
