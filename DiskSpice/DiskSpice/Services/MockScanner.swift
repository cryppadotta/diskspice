import Foundation

@MainActor
class MockScanner: Scanner {
    weak var delegate: ScannerDelegate?
    private(set) var isScanning = false
    private var scanTask: Task<Void, Never>?

    func startScan(at path: URL) async {
        isScanning = true

        scanTask = Task {
            await simulateScan(at: path, depth: 0)
            delegate?.scannerDidComplete(self)
        }

        await scanTask?.value
        isScanning = false
    }

    private func simulateScan(at path: URL, depth: Int) async {
        guard depth < 4 else { return }

        // Simulate processing time
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let childCount = Int.random(in: 3...8)

        for i in 0..<childCount {
            guard !Task.isCancelled else { return }

            let isDir = Bool.random() && depth < 3
            let extensions = ["txt", "pdf", "mp4", "jpg", "swift"]
            let name = isDir ? "Folder_\(i)" : "File_\(i).\(extensions.randomElement()!)"
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

            delegate?.scanner(self, didUpdateNode: node, at: path)
        }

        delegate?.scanner(self, didCompleteFolder: path)
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
