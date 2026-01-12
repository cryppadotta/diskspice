# 004: Create Scanner Protocol and Mock Implementation

## Dependencies
- 003 (core data models)

## Task
Define the scanner protocol interface and create a mock implementation for UI development before the real Rust scanner is ready.

## Spec Reference
See SPEC.md > Scanning Engine section.

## Implementation Details

### ScannerProtocol.swift
Define the interface for any scanner implementation:

```swift
import Foundation

protocol ScannerDelegate: AnyObject {
    func scanner(_ scanner: Scanner, didUpdateNode node: FileNode, at path: URL)
    func scanner(_ scanner: Scanner, didCompleteFolder path: URL)
    func scanner(_ scanner: Scanner, didFailAt path: URL, error: Error)
    func scannerDidComplete(_ scanner: Scanner)
}

protocol Scanner {
    var delegate: ScannerDelegate? { get set }
    var isScanning: Bool { get }

    func startScan(at path: URL) async
    func pauseScan()
    func resumeScan()
    func cancelScan()
    func refreshFolder(at path: URL) async
}
```

### MockScanner.swift
A mock implementation that generates fake data for UI testing:

```swift
import Foundation

actor MockScanner: Scanner {
    weak var delegate: ScannerDelegate?
    private(set) var isScanning = false
    private var scanTask: Task<Void, Never>?

    func startScan(at path: URL) async {
        isScanning = true

        // Simulate scanning delay
        scanTask = Task {
            await simulateScan(at: path, depth: 0)
            await MainActor.run {
                self.delegate?.scannerDidComplete(self)
            }
        }

        await scanTask?.value
        isScanning = false
    }

    private func simulateScan(at path: URL, depth: Int) async {
        guard depth < 4 else { return }

        // Simulate processing time
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let childCount = Int.random(in: 3...8)
        var children: [FileNode] = []

        for i in 0..<childCount {
            let isDir = Bool.random() && depth < 3
            let name = isDir ? "Folder_\(i)" : "File_\(i).\(["txt", "pdf", "mp4", "jpg", "swift"].randomElement()!)"
            let childPath = path.appendingPathComponent(name)
            var node = FileNode(
                path: childPath,
                name: name,
                size: Int64.random(in: 1000...100_000_000),
                isDirectory: isDir
            )
            node.fileType = FileType.allCases.randomElement() ?? .other
            node.scanStatus = .current
            node.lastScanned = Date()

            if isDir {
                await simulateScan(at: childPath, depth: depth + 1)
            }

            children.append(node)

            await MainActor.run {
                self.delegate?.scanner(self, didUpdateNode: node, at: path)
            }
        }

        await MainActor.run {
            self.delegate?.scanner(self, didCompleteFolder: path)
        }
    }

    func pauseScan() {
        // Mock: no-op
    }

    func resumeScan() {
        // Mock: no-op
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    func refreshFolder(at path: URL) async {
        await simulateScan(at: path, depth: 0)
    }
}
```

## Files to Create/Modify
- `DiskSpice/Services/ScannerProtocol.swift` - New file
- `DiskSpice/Services/MockScanner.swift` - New file

## Acceptance Criteria
- [ ] Scanner protocol defines startScan, pause, resume, cancel, refresh methods
- [ ] ScannerDelegate protocol defines update callbacks
- [ ] MockScanner implements Scanner protocol
- [ ] MockScanner generates fake file tree data with random sizes
- [ ] MockScanner calls delegate methods during scan
- [ ] Project builds without errors

## Completion Promise
`<promise>TICKET_004_COMPLETE</promise>`
