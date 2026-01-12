import Foundation

/// Priority levels for scan tasks
enum ScanPriority: Int, Comparable, Sendable {
    case high = 0    // Current directory being viewed
    case medium = 1  // Children of current directory
    case low = 2     // Background/breadth-first scanning

    static func < (lhs: ScanPriority, rhs: ScanPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A task in the scan queue
struct ScanTask: Identifiable, Equatable, Sendable {
    let id = UUID()
    let path: URL
    var priority: ScanPriority
    let depth: Int  // Depth from root for breadth-first ordering

    static func == (lhs: ScanTask, rhs: ScanTask) -> Bool {
        lhs.path == rhs.path
    }
}

/// Manages prioritized scanning queue
@MainActor
@Observable
class ScanQueue {
    var isScanning = false
    var currentTask: ScanTask?
    var queuedCount = 0
    var progress: ScanProgress?

    private var knownScannedPaths: Set<URL> = []
    @ObservationIgnored private let worker = ScanQueueWorker()

    // Callback when directory scan completes
    var onDirectoryScanned: ((URL, [FileNode]) -> Void)?

    init() {
        Task { [weak self] in
            await self?.worker.setUpdateHandler { [weak self] update in
                await self?.handleUpdate(update)
            }
        }
    }

    // MARK: - Public API

    /// Start the background scanning loop
    func startScanning() {
        Task { await worker.startScanning() }
    }

    /// Stop all scanning
    func stopScanning() {
        Task { await worker.stopScanning() }
    }

    /// Prioritize a path (user navigated to it)
    func prioritize(path: URL) {
        Task { await worker.prioritize(path: path) }
    }

    /// Add a path to the queue (background priority)
    func enqueue(path: URL, priority: ScanPriority = .low) {
        Task { await worker.enqueue(path: path, priority: priority) }
    }

    /// Add multiple paths to the queue
    func enqueue(paths: [URL], priority: ScanPriority = .low) {
        Task { await worker.enqueue(paths: paths, priority: priority) }
    }

    /// Check if a path needs scanning
    func needsScan(path: URL) -> Bool {
        !knownScannedPaths.contains(path)
    }

    /// Mark a path as scanned (e.g., if scanned externally)
    func markScanned(path: URL) {
        Task { await worker.markScanned(path: path) }
    }

    /// Clear the queue and scanned state
    func reset() {
        Task { await worker.reset() }
    }

    // MARK: - Worker Updates

    private func handleUpdate(_ update: ScanQueueUpdate) {
        switch update {
        case .isScanning(let value):
            isScanning = value
        case .currentTask(let task):
            currentTask = task
        case .queuedCount(let count):
            queuedCount = count
        case .progress(let progress):
            self.progress = progress
        case .directoryScanned(let path, let children):
            knownScannedPaths.insert(path)
            onDirectoryScanned?(path, children)
        case .scanLoopEnded:
            isScanning = false
            currentTask = nil
            progress = nil
        }
    }
}

// MARK: - Worker update types

enum ScanQueueUpdate: Sendable {
    case isScanning(Bool)
    case currentTask(ScanTask?)
    case queuedCount(Int)
    case progress(ScanProgress)
    case directoryScanned(URL, [FileNode])
    case scanLoopEnded
}

// MARK: - Background scan worker

actor ScanQueueWorker {
    private var updateHandler: (@Sendable (ScanQueueUpdate) async -> Void)?
    private var scanTask: Task<Void, Never>?
    private let scanWorker = SwiftScanWorker()

    private var tasks: [ScanTask] = []
    private var scannedPaths: Set<URL> = []

    // Cumulative stats across all scans
    private var totalFilesScanned: Int = 0
    private var totalBytesScanned: Int64 = 0
    private var scanStartTime: Date?

    // Progress update throttling - use longer interval to avoid UI churn
    private var lastProgressUpdate: Date = .distantPast
    private let progressUpdateInterval: TimeInterval = 0.5  // Update at most every 500ms
    private var lastQueueCountUpdate: Date = .distantPast

    func setUpdateHandler(_ handler: @escaping @Sendable (ScanQueueUpdate) async -> Void) {
        updateHandler = handler
    }

    func startScanning() {
        guard scanTask == nil else { return }
        scanTask = Task { [weak self] in
            await self?.scanLoop()
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        Task { await sendUpdate(.scanLoopEnded) }
    }

    func reset() {
        stopScanning()
        tasks.removeAll()
        scannedPaths.removeAll()
        Task { await sendUpdate(.queuedCount(0)) }
    }

    func prioritize(path: URL) {
        debugLog("ScanQueue: prioritizing \(path.path)", category: "QUEUE")

        if scannedPaths.contains(path) {
            queueChildrenIfNeeded(of: path, priority: .high)
            return
        }

        tasks.removeAll { $0.path == path }
        let task = ScanTask(path: path, priority: .high, depth: pathDepth(path))
        tasks.insert(task, at: 0)

        updateQueueCount()
        startScanning()
    }

    func enqueue(path: URL, priority: ScanPriority = .low) {
        guard !scannedPaths.contains(path) else { return }
        guard !tasks.contains(where: { $0.path == path }) else { return }

        let task = ScanTask(path: path, priority: priority, depth: pathDepth(path))

        if let insertIndex = tasks.firstIndex(where: { $0.priority > priority || ($0.priority == priority && $0.depth > task.depth) }) {
            tasks.insert(task, at: insertIndex)
        } else {
            tasks.append(task)
        }

        updateQueueCount()
    }

    func enqueue(paths: [URL], priority: ScanPriority = .low) {
        for path in paths {
            enqueue(path: path, priority: priority)
        }
    }

    func needsScan(path: URL) -> Bool {
        !scannedPaths.contains(path)
    }

    func markScanned(path: URL) {
        scannedPaths.insert(path)
        tasks.removeAll { $0.path == path }
        updateQueueCount()
    }

    // MARK: - Scan loop

    private func scanLoop() async {
        debugLog("ScanQueue: starting scan loop", category: "QUEUE")
        if scanStartTime == nil {
            scanStartTime = Date()
        }

        while !Task.isCancelled {
            guard let task = popNextTask() else {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            if scannedPaths.contains(task.path) {
                continue
            }

            await sendUpdate(.currentTask(task))
            await sendUpdate(.isScanning(true))
            updateProgressThrottled(path: task.path.path)

            let children = await scanWorker.scanDirectory(at: task.path)

            totalFilesScanned += children.count
            for child in children {
                totalBytesScanned += child.size
            }

            updateProgressThrottled(path: task.path.path, force: true)
            scannedPaths.insert(task.path)
            await sendUpdate(.directoryScanned(task.path, children))

            let childPriority: ScanPriority = task.priority == .high ? .medium : .low
            for child in children where child.isDirectory {
                if case .current = child.scanStatus {
                    continue
                }
                enqueue(path: child.path, priority: childPriority)
            }

            debugLog("ScanQueue: completed \(task.path.path), found \(children.count) children, total scanned: \(totalFilesScanned)", category: "QUEUE")
            updateQueueCount()
        }

        debugLog("ScanQueue: scan loop ended", category: "QUEUE")
        await sendUpdate(.scanLoopEnded)
    }

    private func popNextTask() -> ScanTask? {
        guard !tasks.isEmpty else { return nil }
        return tasks.removeFirst()
    }

    private func queueChildrenIfNeeded(of path: URL, priority: ScanPriority) {
        debugLog("ScanQueue: path already scanned, checking children", category: "QUEUE")
    }

    private func pathDepth(_ path: URL) -> Int {
        path.pathComponents.count
    }

    private func updateQueueCount() {
        let now = Date()
        guard now.timeIntervalSince(lastQueueCountUpdate) >= 0.5 else { return }
        lastQueueCountUpdate = now
        Task { await sendUpdate(.queuedCount(tasks.count)) }
    }

    private func updateProgressThrottled(path: String, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval else {
            return
        }
        lastProgressUpdate = now

        Task {
            await sendUpdate(.progress(ScanProgress(
                currentPath: path,
                filesScanned: totalFilesScanned,
                bytesScanned: totalBytesScanned,
                startTime: scanStartTime ?? Date()
            )))
        }
    }

    private func sendUpdate(_ update: ScanQueueUpdate) async {
        await updateHandler?(update)
    }
}

actor SwiftScanWorker {
    private let scanner = SwiftScanner()

    func scanDirectory(at path: URL) async -> [FileNode] {
        await scanner.scanDirectory(at: path)
    }
}
