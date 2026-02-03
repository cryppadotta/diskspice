import Foundation

@MainActor
class RustScanner: Scanner {
    weak var delegate: ScannerDelegate?
    private(set) var isScanning = false

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var pendingEntries: [ScanEntry] = []
    private var flushTask: Task<Void, Never>?
    private let flushInterval: Duration = .milliseconds(80)
    private var readTask: Task<Void, Never>?
    private var currentSessionId: Int = 0
    private var cancelledSessionId: Int?

    private var scannerPath: URL? {
        Bundle.main.url(forResource: "diskspice-scan", withExtension: nil, subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "diskspice-scan", withExtension: nil)
    }

    func startScan(at path: URL) async {
        guard !isScanning else { return }
        guard let scannerURL = scannerPath else {
            delegate?.scanner(self, didFailAt: path, error: ScanError.scannerNotFound)
            return
        }

        currentSessionId &+= 1
        let sessionId = currentSessionId
        cancelledSessionId = nil
        isScanning = true
        pendingEntries.removeAll()
        flushTask?.cancel()
        flushTask = nil
        readTask?.cancel()
        readTask = nil

        let process = Process()
        process.executableURL = scannerURL
        process.arguments = [path.path]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe

        // Read output in background
        let outputHandle = stdoutPipe.fileHandleForReading
        readTask = Task.detached { [weak self] in
            await self?.readOutput(from: outputHandle, basePath: path, sessionId: sessionId)
        }

        do {
            try process.run()

            // Wait for process in background
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
        } catch {
            delegate?.scanner(self, didFailAt: path, error: error)
        }

        if let readTask {
            _ = await readTask.value
        }
        let wasCancelled = cancelledSessionId == sessionId
        if !wasCancelled {
            flushPendingEntries()
        }
        isScanning = false
        if !wasCancelled {
            delegate?.scannerDidComplete(self)
        }
    }

    private func readOutput(from handle: FileHandle, basePath: URL, sessionId: Int) async {
        var buffer = Data()

        while true {
            if Task.isCancelled || sessionId != currentSessionId || cancelledSessionId == sessionId {
                break
            }
            let data = handle.availableData
            if data.isEmpty {
                // Process any remaining data in buffer
                if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
                    await processLine(line, basePath: basePath, sessionId: sessionId)
                }
                break
            }

            buffer.append(data)

            // Process complete lines
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newlineIndex]
                buffer = buffer[(newlineIndex + 1)...]

                if let line = String(data: lineData, encoding: .utf8) {
                    await processLine(line, basePath: basePath, sessionId: sessionId)
                }
            }
        }
    }

    private func processLine(_ line: String, basePath: URL, sessionId: Int) async {
        guard sessionId == currentSessionId, cancelledSessionId != sessionId else { return }
        guard !line.isEmpty, let data = line.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(RustScanMessage.self, from: data)
            await MainActor.run {
                self.handleMessage(message, basePath: basePath, sessionId: sessionId)
            }
        } catch {
            // Ignore malformed lines
        }
    }

    private func handleMessage(_ message: RustScanMessage, basePath: URL, sessionId: Int) {
        guard sessionId == currentSessionId, cancelledSessionId != sessionId else { return }
        switch message {
        case .entry(let entry):
            bufferEntry(entry)

        case .folderComplete(let path, _):
            flushPendingEntries()
            delegate?.scanner(self, didCompleteFolder: URL(fileURLWithPath: path))

        case .error(let path, let message):
            flushPendingEntries()
            let error = ScanError.scanFailed(message)
            delegate?.scanner(self, didFailAt: URL(fileURLWithPath: path), error: error)

        case .status(_):
            // Handle status updates if needed
            break

        case .done(_, _):
            flushPendingEntries()
            // Final completion handled in startScan
            break
        }
    }

    func pauseScan() {
        sendCommand("pause")
    }

    func resumeScan() {
        sendCommand("resume")
    }

    func cancelScan() {
        sendCommand("cancel")
        process?.terminate()
        cancelledSessionId = currentSessionId
        readTask?.cancel()
        flushTask?.cancel()
        pendingEntries.removeAll()
        isScanning = false
    }

    func refreshFolder(at path: URL) async {
        sendCommand("refresh:\(path.path)")
    }

    private func sendCommand(_ command: String) {
        guard let pipe = stdinPipe else { return }
        if let data = (command + "\n").data(using: .utf8) {
            pipe.fileHandleForWriting.write(data)
        }
    }

    private func bufferEntry(_ entry: ScanEntry) {
        pendingEntries.append(entry)
        if flushTask == nil {
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: self?.flushInterval ?? .milliseconds(80))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.flushPendingEntries()
                }
            }
        }
    }

    private func flushPendingEntries() {
        guard !pendingEntries.isEmpty else { return }
        let entries = pendingEntries
        pendingEntries.removeAll()
        flushTask?.cancel()
        flushTask = nil

        for entry in entries {
            let node = FileNode(from: entry)
            let parentPath = URL(fileURLWithPath: entry.path).deletingLastPathComponent()
            delegate?.scanner(self, didUpdateNode: node, at: parentPath)
        }
    }
}

// MARK: - Supporting Types

enum ScanError: Error, LocalizedError {
    case scannerNotFound
    case scanFailed(String)

    var errorDescription: String? {
        switch self {
        case .scannerNotFound:
            return "Scanner binary not found in app bundle"
        case .scanFailed(let message):
            return message
        }
    }
}

enum RustScanMessage: Decodable {
    case entry(ScanEntry)
    case folderComplete(path: String, totalSize: Int64)
    case error(path: String, message: String)
    case status(status: String)
    case done(totalSize: Int64, totalItems: Int64)

    enum CodingKeys: String, CodingKey {
        case type, path, size, name
        case isDir = "is_dir"
        case isSymlink = "is_symlink"
        case modified
        case itemCount = "item_count"
        case fileType = "file_type"
        case totalSize = "total_size"
        case totalItems = "total_items"
        case message, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "entry":
            let entry = ScanEntry(
                path: try container.decode(String.self, forKey: .path),
                name: try container.decode(String.self, forKey: .name),
                size: try container.decode(Int64.self, forKey: .size),
                isDir: try container.decode(Bool.self, forKey: .isDir),
                isSymlink: try container.decode(Bool.self, forKey: .isSymlink),
                modified: try container.decodeIfPresent(Int64.self, forKey: .modified),
                itemCount: try container.decode(Int64.self, forKey: .itemCount),
                fileType: try container.decode(String.self, forKey: .fileType)
            )
            self = .entry(entry)

        case "complete":
            self = .folderComplete(
                path: try container.decode(String.self, forKey: .path),
                totalSize: try container.decode(Int64.self, forKey: .totalSize)
            )

        case "error":
            self = .error(
                path: try container.decode(String.self, forKey: .path),
                message: try container.decode(String.self, forKey: .message)
            )

        case "status":
            self = .status(status: try container.decode(String.self, forKey: .status))

        case "done":
            self = .done(
                totalSize: try container.decode(Int64.self, forKey: .totalSize),
                totalItems: try container.decode(Int64.self, forKey: .totalItems)
            )

        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown type: \(type)"))
        }
    }
}

struct ScanEntry {
    let path: String
    let name: String
    let size: Int64
    let isDir: Bool
    let isSymlink: Bool
    let modified: Int64?
    let itemCount: Int64
    let fileType: String
}

// MARK: - FileNode Extension

extension FileNode {
    init(from entry: ScanEntry) {
        self.init(
            path: URL(fileURLWithPath: entry.path),
            name: entry.name,
            size: entry.size,
            isDirectory: entry.isDir
        )
        self.isSymlink = entry.isSymlink
        self.itemCount = Int(entry.itemCount)
        self.modifiedDate = entry.modified.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.fileType = FileType(rawValue: entry.fileType) ?? .other
        self.scanStatus = .current
        self.lastScanned = Date()
    }
}
