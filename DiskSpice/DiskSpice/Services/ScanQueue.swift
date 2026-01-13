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
    var isCompleted = false
    var currentTask: ScanTask?
    var queuedCount = 0
    var progress: ScanProgress?

    private var knownScannedPaths: Set<URL> = []
    @ObservationIgnored private let worker = ScanQueueWorker()

    // Callback when directory scan completes
    var onDirectoryScanned: ((URL, [FileNode], Bool) -> Void)?
    var onDirectoryProgress: ((URL, Int, Int64) -> Void)?

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
        Task { await worker.prioritize(path: path, force: false) }
    }

    func prioritize(path: URL, force: Bool) {
        if force {
            knownScannedPaths = knownScannedPaths.filter { !pathHasPrefix($0, prefix: path) }
        }
        Task { await worker.prioritize(path: path, force: force) }
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
            if value {
                isCompleted = false
            }
        case .currentTask(let task):
            currentTask = task
        case .queuedCount(let count):
            queuedCount = count
        case .progress(let progress):
            self.progress = progress
        case .directoryScanned(let path, let children, let isComplete):
            if isComplete {
                knownScannedPaths.insert(path)
            }
            onDirectoryScanned?(path, children, isComplete)
        case .directoryProgress(let path, let filesScanned, let bytesScanned):
            onDirectoryProgress?(path, filesScanned, bytesScanned)
        case .scanLoopEnded(let completed):
            isScanning = false
            currentTask = nil
            progress = nil
            isCompleted = completed
        }
    }

    private func pathHasPrefix(_ path: URL, prefix: URL) -> Bool {
        path.path.hasPrefix(prefix.path)
    }
}

// MARK: - Worker update types

enum ScanQueueUpdate: Sendable {
    case isScanning(Bool)
    case currentTask(ScanTask?)
    case queuedCount(Int)
    case progress(ScanProgress)
    case directoryScanned(URL, [FileNode], Bool)
    case directoryProgress(URL, Int, Int64)
    case scanLoopEnded(Bool)
}

// MARK: - Background scan worker

actor ScanQueueWorker {
    private var updateHandler: (@Sendable (ScanQueueUpdate) async -> Void)?
    private var scanTask: Task<Void, Never>?

    private var tasks: [ScanTask] = []
    private var deferredTasks: [ScanTask] = []
    private var scannedPaths: Set<URL> = []
    private var focusRoot: URL?
    private var completedExclusiveFocus = false
    private let exclusiveFocusMode = true
    private var partialOffsets: [URL: Int] = [:]
    private var inFlight: Set<URL> = []
    private let maxConcurrentScans = 2
    private let maxQueuedTasks = 200

    // Cumulative stats across all scans
    private var totalFilesScanned: Int = 0
    private var totalBytesScanned: Int64 = 0
    private var scanStartTime: Date?

    // Progress update throttling - use longer interval to avoid UI churn
    private var lastProgressUpdate: Date = .distantPast
    private let progressUpdateInterval: TimeInterval = 0.5  // Update at most every 500ms
    private var lastQueueCountUpdate: Date = .distantPast
    private var lastDirectoryProgressUpdate: Date = .distantPast
    private let directoryProgressInterval: TimeInterval = 0.1

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
        Task { await sendUpdate(.scanLoopEnded(false)) }
    }

    func reset() {
        stopScanning()
        tasks.removeAll()
        deferredTasks.removeAll()
        scannedPaths.removeAll()
        inFlight.removeAll()
        Task { await sendUpdate(.queuedCount(0)) }
    }

    func prioritize(path: URL, force: Bool) {
        debugLog("ScanQueue: prioritizing \(path.path)", category: "QUEUE")

        if scannedPaths.contains(path) && !force {
            focusRoot = path
            queueChildrenIfNeeded(of: path, priority: .high)
            return
        }

        if force {
            scannedPaths = scannedPaths.filter { !pathHasPrefix($0, prefix: path) }
        }

        focusRoot = path
        completedExclusiveFocus = false
        if exclusiveFocusMode {
            tasks = tasks.filter { pathHasPrefix($0.path, prefix: path) }
            deferredTasks = deferredTasks.filter { pathHasPrefix($0.path, prefix: path) }
        }
        tasks.removeAll { $0.path == path }
        let task = ScanTask(path: path, priority: .high, depth: pathDepth(path))
        tasks.insert(task, at: 0)

        updateQueueCount()
        startScanning()
    }

    func enqueue(path: URL, priority: ScanPriority = .low) {
        guard !scannedPaths.contains(path) else { return }
        guard !containsTask(path: path) else { return }

        let resolvedPriority: ScanPriority
        if let focusRoot, pathHasPrefix(path, prefix: focusRoot) {
            resolvedPriority = .high
        } else if exclusiveFocusMode && focusRoot != nil {
            return
        } else {
            resolvedPriority = priority
        }

        let task = ScanTask(path: path, priority: resolvedPriority, depth: pathDepth(path))
        enqueueTask(task)

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
        deferredTasks.removeAll { $0.path == path }
        updateQueueCount()
    }

    // MARK: - Scan loop

    private func scanLoop() async {
        debugLog("ScanQueue: starting scan loop", category: "QUEUE")
        if scanStartTime == nil {
            scanStartTime = Date()
        }

        while !Task.isCancelled {
            drainDeferredTasksIfNeeded()
            while inFlight.count < maxConcurrentScans {
                guard let task = popNextTask() else { break }
                if scannedPaths.contains(task.path) {
                    continue
                }
                startScanTask(task)
            }

            if inFlight.isEmpty && tasks.isEmpty {
                if completedExclusiveFocus {
                    await sendUpdate(.scanLoopEnded(true))
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            } else {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        debugLog("ScanQueue: scan loop ended", category: "QUEUE")
        await sendUpdate(.scanLoopEnded(false))
    }

    private func startScanTask(_ task: ScanTask) {
        inFlight.insert(task.path)
        if inFlight.count == 1 {
            Task { await sendUpdate(.isScanning(true)) }
        }
        Task { await sendUpdate(.currentTask(task)) }
        updateProgressThrottled(path: task.path.path)
        Task { [weak self] in
            guard let self else { return }
            let scannedAt = Date()
            let offset = await self.offsetForPath(task.path)
            let result = await self.performScan(task: task, offset: offset)
            await self.handleScanResult(task: task, scannedAt: scannedAt, result: result)
        }
    }

    private func offsetForPath(_ path: URL) -> Int {
        partialOffsets[path] ?? 0
    }

    nonisolated private func performScan(task: ScanTask, offset: Int) async -> ScanDirectoryResult {
        let scanner = SwiftScanner()
        scanner.setProgressCallback { _, filesScanned, bytesScanned in
            Task { [weak self] in
                await self?.updateDirectoryProgressThrottled(
                    path: task.path,
                    filesScanned: filesScanned,
                    bytesScanned: bytesScanned
                )
            }
        }
        let result = await scanner.scanDirectory(at: task.path, startingAt: offset)
        scanner.clearProgressCallback()
        return result
    }

    private func handleScanResult(task: ScanTask, scannedAt: Date, result: ScanDirectoryResult) async {
        let childrenWithMetadata = result.nodes.map { child -> FileNode in
            var node = child
            if node.lastScanned == nil {
                node.lastScanned = scannedAt
            }
            return node
        }

        updateProgressThrottled(path: task.path.path, force: true)

        totalFilesScanned += childrenWithMetadata.count
        for child in childrenWithMetadata {
            totalBytesScanned += child.size
        }

        if result.isComplete {
            scannedPaths.insert(task.path)
            partialOffsets.removeValue(forKey: task.path)
        } else {
            partialOffsets[task.path] = result.nextOffset
        }

        await sendUpdate(.directoryScanned(task.path, childrenWithMetadata, result.isComplete))

        if result.isComplete {
            let childPriority: ScanPriority = task.priority == .high ? .medium : .low
            for child in childrenWithMetadata where child.isDirectory {
                if case .current = child.scanStatus {
                    continue
                }
                enqueue(path: child.path, priority: childPriority)
            }
        } else {
            enqueue(path: task.path, priority: .high)
        }

        inFlight.remove(task.path)
        debugLog("ScanQueue: completed \(task.path.path), found \(childrenWithMetadata.count) children, total scanned: \(totalFilesScanned)", category: "QUEUE")
        updateQueueCount()
        if inFlight.isEmpty && tasks.isEmpty {
            await sendUpdate(.scanLoopEnded(completedExclusiveFocus))
        }
    }

    private func popNextTask() -> ScanTask? {
        if tasks.isEmpty {
            drainDeferredTasksIfNeeded()
        }
        guard !tasks.isEmpty else { return nil }
        if let focusRoot {
            let focusIndices = tasks.enumerated().filter { pathHasPrefix($0.element.path, prefix: focusRoot) }
            if let deepest = focusIndices.max(by: { $0.element.depth < $1.element.depth }) {
                return tasks.remove(at: deepest.offset)
            }
            if exclusiveFocusMode {
                tasks.removeAll()
                self.focusRoot = nil
                completedExclusiveFocus = true
                return nil
            }
            self.focusRoot = nil
        }
        return tasks.removeFirst()
    }

    private func enqueueTask(_ task: ScanTask) {
        if task.priority == .high || !shouldDeferEnqueue {
            insertTask(task)
            return
        }
        deferredTasks.append(task)
    }

    private func insertTask(_ task: ScanTask) {
        if let insertIndex = tasks.firstIndex(where: { $0.priority > task.priority || ($0.priority == task.priority && $0.depth > task.depth) }) {
            tasks.insert(task, at: insertIndex)
        } else {
            tasks.append(task)
        }
    }

    private func drainDeferredTasksIfNeeded() {
        guard !deferredTasks.isEmpty else { return }
        guard tasks.count < maxQueuedTasks || inFlight.count < maxConcurrentScans else { return }
        while !deferredTasks.isEmpty && tasks.count < maxQueuedTasks {
            let task = deferredTasks.removeFirst()
            if !scannedPaths.contains(task.path) && !tasks.contains(where: { $0.path == task.path }) {
                insertTask(task)
            }
        }
    }

    private var shouldDeferEnqueue: Bool {
        inFlight.count >= maxConcurrentScans && tasks.count >= maxQueuedTasks
    }

    private func containsTask(path: URL) -> Bool {
        tasks.contains(where: { $0.path == path }) || deferredTasks.contains(where: { $0.path == path })
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
        Task { await sendUpdate(.queuedCount(tasks.count + deferredTasks.count)) }
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

    private func updateDirectoryProgressThrottled(path: URL, filesScanned: Int, bytesScanned: Int64) async {
        let now = Date()
        guard now.timeIntervalSince(lastDirectoryProgressUpdate) >= directoryProgressInterval else {
            return
        }
        lastDirectoryProgressUpdate = now
        await sendUpdate(.directoryProgress(path, filesScanned, bytesScanned))
    }

    private func pathHasPrefix(_ path: URL, prefix: URL) -> Bool {
        path.path.hasPrefix(prefix.path)
    }
}
