# 010: Create Swift Wrapper for Rust Scanner

## Dependencies
- 004 (scanner protocol)
- 009 (build scanner binary)

## Task
Create a Swift class that wraps the Rust scanner binary, managing the process lifecycle, parsing JSON output, and conforming to the Scanner protocol.

## Spec Reference
See SPEC.md > Scanning Engine: integration between Swift app and Rust binary.

## Implementation Details

### RustScanner.swift

```swift
import Foundation

actor RustScanner: Scanner {
    weak var delegate: ScannerDelegate?
    private(set) var isScanning = false

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    private var scannerPath: URL {
        Bundle.main.url(forResource: "diskspice-scan", withExtension: nil)!
    }

    func startScan(at path: URL) async {
        guard !isScanning else { return }
        isScanning = true

        let process = Process()
        process.executableURL = scannerPath
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
        Task {
            await readOutput(from: stdoutPipe, basePath: path)
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            await MainActor.run {
                self.delegate?.scanner(self, didFailAt: path, error: error)
            }
        }

        isScanning = false
        await MainActor.run {
            self.delegate?.scannerDidComplete(self)
        }
    }

    private func readOutput(from pipe: Pipe, basePath: URL) async {
        let handle = pipe.fileHandleForReading

        while let line = await readLine(from: handle) {
            await processLine(line, basePath: basePath)
        }
    }

    private func readLine(from handle: FileHandle) async -> String? {
        // Read line-by-line from the pipe
        var buffer = Data()

        while true {
            let data = handle.availableData
            if data.isEmpty {
                return buffer.isEmpty ? nil : String(data: buffer, encoding: .utf8)
            }

            for byte in data {
                if byte == 0x0A { // newline
                    return String(data: buffer, encoding: .utf8)
                }
                buffer.append(byte)
            }
        }
    }

    private func processLine(_ line: String, basePath: URL) async {
        guard let data = line.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(ScanMessage.self, from: data)
            await handleMessage(message, basePath: basePath)
        } catch {
            // Ignore malformed lines
        }
    }

    private func handleMessage(_ message: ScanMessage, basePath: URL) async {
        switch message {
        case .entry(let entry):
            let node = FileNode(from: entry)
            await MainActor.run {
                self.delegate?.scanner(self, didUpdateNode: node, at: URL(fileURLWithPath: entry.path).deletingLastPathComponent())
            }

        case .folderComplete(let path, _):
            await MainActor.run {
                self.delegate?.scanner(self, didCompleteFolder: URL(fileURLWithPath: path))
            }

        case .error(let path, let message):
            let error = ScanError.scanFailed(message)
            await MainActor.run {
                self.delegate?.scanner(self, didFailAt: URL(fileURLWithPath: path), error: error)
            }

        case .status(_):
            // Handle status updates if needed
            break

        case .done(_, _):
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
        isScanning = false
    }

    func refreshFolder(at path: URL) async {
        sendCommand("refresh:\(path.path)")
    }

    private func sendCommand(_ command: String) {
        guard let pipe = stdinPipe else { return }
        let data = (command + "\n").data(using: .utf8)!
        pipe.fileHandleForWriting.write(data)
    }
}

// MARK: - Supporting Types

enum ScanError: Error {
    case scanFailed(String)
}

enum ScanMessage: Decodable {
    case entry(ScanEntry)
    case folderComplete(path: String, totalSize: Int64)
    case error(path: String, message: String)
    case status(status: String)
    case done(totalSize: Int64, totalItems: Int64)

    enum CodingKeys: String, CodingKey {
        case type, path, size, name, isDir = "is_dir", isSymlink = "is_symlink"
        case modified, itemCount = "item_count", fileType = "file_type"
        case totalSize = "total_size", totalItems = "total_items"
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
```

## Files to Create/Modify
- `DiskSpice/Services/RustScanner.swift` - New file

## Acceptance Criteria
- [ ] RustScanner conforms to Scanner protocol
- [ ] RustScanner locates scanner binary in app bundle
- [ ] startScan launches process and reads JSON output
- [ ] JSON messages are parsed into FileNode objects
- [ ] Delegate methods are called on MainActor
- [ ] pauseScan/resumeScan/cancelScan send commands via stdin
- [ ] cancelScan terminates the process
- [ ] Error handling for process launch failures
- [ ] Project builds without errors

## Completion Promise
`<promise>TICKET_010_COMPLETE</promise>`
