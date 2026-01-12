import Foundation

/// Priority levels for scan tasks
enum ScanPriority: Int, Comparable {
    case high = 0    // Current directory being viewed
    case medium = 1  // Children of current directory
    case low = 2     // Background/breadth-first scanning

    static func < (lhs: ScanPriority, rhs: ScanPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A task in the scan queue
struct ScanTask: Identifiable, Equatable {
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

    // Cumulative stats across all scans
    private var totalFilesScanned: Int = 0
    private var totalBytesScanned: Int64 = 0
    private var scanStartTime: Date?

    // Progress update throttling - use longer interval to avoid UI churn
    private var lastProgressUpdate: Date = .distantPast
    private let progressUpdateInterval: TimeInterval = 0.5  // Update at most every 500ms

    private var tasks: [ScanTask] = []
    private var scannedPaths: Set<URL> = []
    private var scanTask: Task<Void, Never>?
    private let scanWorker = SwiftScanWorker()

    // Callback when directory scan completes
    var onDirectoryScanned: ((URL, [FileNode]) -> Void)?

    // MARK: - Public API

    /// Start the background scanning loop
    func startScanning() {
        guard scanTask == nil else { return }

        scanTask = Task { [weak self] in
            await self?.scanLoop()
        }
    }

    /// Stop all scanning
    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentTask = nil
    }

    /// Prioritize a path (user navigated to it)
    func prioritize(path: URL) {
        debugLog("ScanQueue: prioritizing \(path.path)", category: "QUEUE")

        // If already scanned, just scan children at high priority
        if scannedPaths.contains(path) {
            queueChildrenIfNeeded(of: path, priority: .high)
            return
        }

        // Remove existing task for this path (if any)
        tasks.removeAll { $0.path == path }

        // Add with high priority at front
        let task = ScanTask(path: path, priority: .high, depth: pathDepth(path))
        tasks.insert(task, at: 0)

        updateQueueCount()

        // Start scanning if not already
        if scanTask == nil {
            startScanning()
        }
    }

    /// Add a path to the queue (background priority)
    func enqueue(path: URL, priority: ScanPriority = .low) {
        guard !scannedPaths.contains(path) else { return }
        guard !tasks.contains(where: { $0.path == path }) else { return }

        let task = ScanTask(path: path, priority: priority, depth: pathDepth(path))

        // Insert at appropriate position based on priority and depth
        if let insertIndex = tasks.firstIndex(where: { $0.priority > priority || ($0.priority == priority && $0.depth > task.depth) }) {
            tasks.insert(task, at: insertIndex)
        } else {
            tasks.append(task)
        }

        updateQueueCount()
    }

    /// Add multiple paths to the queue
    func enqueue(paths: [URL], priority: ScanPriority = .low) {
        for path in paths {
            enqueue(path: path, priority: priority)
        }
    }

    /// Check if a path needs scanning
    func needsScan(path: URL) -> Bool {
        !scannedPaths.contains(path)
    }

    /// Mark a path as scanned (e.g., if scanned externally)
    func markScanned(path: URL) {
        scannedPaths.insert(path)
        tasks.removeAll { $0.path == path }
        updateQueueCount()
    }

    /// Clear the queue and scanned state
    func reset() {
        stopScanning()
        tasks.removeAll()
        scannedPaths.removeAll()
        updateQueueCount()
    }

    // MARK: - Private

    private func scanLoop() async {
        debugLog("ScanQueue: starting scan loop", category: "QUEUE")

        // Initialize scan start time if not set
        if scanStartTime == nil {
            scanStartTime = Date()
        }

        while !Task.isCancelled {
            // Get next task
            guard let task = popNextTask() else {
                // Queue empty, wait a bit then check again
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            // Skip if already scanned
            if scannedPaths.contains(task.path) {
                continue
            }

            // Update state
            currentTask = task
            isScanning = true

            // Throttled progress update - only update UI if enough time passed
            updateProgressThrottled(path: task.path.path)

            // Perform scan off the main actor
            let children = await scanWorker.scanDirectory(at: task.path)

            // Update cumulative stats
            totalFilesScanned += children.count
            for child in children {
                totalBytesScanned += child.size
            }

            // Force progress update after each directory completes
            updateProgressThrottled(path: task.path.path, force: true)

            // Mark as scanned
            scannedPaths.insert(task.path)

            // Notify callback
            onDirectoryScanned?(task.path, children)

            // Queue children for scanning (at lower priority)
            // Skip directories already marked as .current (e.g., node_modules sized with du)
            let childPriority: ScanPriority = task.priority == .high ? .medium : .low
            for child in children where child.isDirectory {
                if case .current = child.scanStatus {
                    // Already fully scanned (e.g., node_modules), don't queue
                    continue
                }
                enqueue(path: child.path, priority: childPriority)
            }

            debugLog("ScanQueue: completed \(task.path.path), found \(children.count) children, total scanned: \(totalFilesScanned)", category: "QUEUE")

            updateQueueCount()
        }

        debugLog("ScanQueue: scan loop ended", category: "QUEUE")
        isScanning = false
        currentTask = nil
        progress = nil
    }

    private func popNextTask() -> ScanTask? {
        guard !tasks.isEmpty else { return nil }
        return tasks.removeFirst()
    }

    private func queueChildrenIfNeeded(of path: URL, priority: ScanPriority) {
        // Get cached children and queue unscanned ones
        // This would need to integrate with AppState's file tree
        // For now, we just mark this as done
        debugLog("ScanQueue: path already scanned, checking children", category: "QUEUE")
    }

    private func pathDepth(_ path: URL) -> Int {
        path.pathComponents.count
    }

    private var lastQueueCountUpdate: Date = .distantPast

    private func updateQueueCount() {
        // Throttle queue count updates too
        let now = Date()
        guard now.timeIntervalSince(lastQueueCountUpdate) >= 0.5 else { return }
        lastQueueCountUpdate = now
        queuedCount = tasks.count
    }

    /// Update progress only if enough time has passed (throttled)
    private func updateProgressThrottled(path: String, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval else {
            return
        }
        lastProgressUpdate = now

        progress = ScanProgress(
            currentPath: path,
            filesScanned: totalFilesScanned,
            bytesScanned: totalBytesScanned,
            startTime: scanStartTime ?? Date()
        )
    }
}

// MARK: - Background scan worker

actor SwiftScanWorker {
    private let scanner = SwiftScanner()

    func scanDirectory(at path: URL) async -> [FileNode] {
        await scanner.scanDirectory(at: path)
    }
}
