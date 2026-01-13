import Foundation

/// Progress callback for scan updates
typealias ScanProgressCallback = (String, Int, Int64) -> Void

/// Directories that should use fast `du` sizing instead of recursive enumeration
private let heavyDirectoryNames: Set<String> = [
    "node_modules",
    ".git",
    "__pycache__",
    ".gradle",
    "Pods",
    "DerivedData",
    ".build",
    "vendor",
    "bower_components"
]

struct ScanDirectoryResult {
    let nodes: [FileNode]
    let isComplete: Bool
    let nextOffset: Int
}

/// Simple Swift-based directory scanner for immediate children
/// Used for quick directory listing without the full Rust scanner
class SwiftScanner {

    private let fileManager = FileManager.default
    private var progressCallback: ScanProgressCallback?
    private var filesScanned: Int = 0
    private var bytesScanned: Int64 = 0
    private let scanTimeBudget: TimeInterval = 0.05
    private let maxEntriesPerPass: Int = 200
    private let sampleTimeBudget: TimeInterval = 0.02
    private let sampleEntryLimit: Int = 32

    /// Set progress callback for scan updates
    func setProgressCallback(_ callback: @escaping ScanProgressCallback) {
        self.progressCallback = callback
    }

    func clearProgressCallback() {
        progressCallback = nil
    }

    /// Report progress to callback
    private func reportProgress(path: String, size: Int64 = 0) {
        filesScanned += 1
        bytesScanned += size
        progressCallback?(path, filesScanned, bytesScanned)
    }

    /// Check if a directory is a "heavy" directory that should use fast sizing
    private func isHeavyDirectory(_ url: URL) -> Bool {
        heavyDirectoryNames.contains(url.lastPathComponent)
    }

    /// Get directory size quickly using `du` command
    /// Returns size in bytes, or nil if failed
    private func getDirectorySizeWithDu(_ url: URL) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]  // -s for summary, -k for kilobytes

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let sizeStr = output.split(separator: "\t").first,
               let sizeKB = Int64(sizeStr) {
                return sizeKB * 1024  // Convert KB to bytes
            }
        } catch {
            debugLog("du failed for \(url.path): \(error)", category: "SCAN")
        }
        return nil
    }

    /// Count items in a directory quickly (non-recursive)
    private func countDirectoryItems(_ url: URL) -> Int {
        (try? fileManager.contentsOfDirectory(atPath: url.path).count) ?? 0
    }

    private let resourceKeys: [URLResourceKey] = [
        .fileSizeKey,
        .fileAllocatedSizeKey,
        .totalFileSizeKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .contentModificationDateKey,
        .totalFileAllocatedSizeKey
    ]

    /// Scan immediate children of a directory
    func scanDirectory(at path: URL, startingAt offset: Int, forceFullPass: Bool = false) async -> ScanDirectoryResult {
        // Reset counters for new scan
        filesScanned = 0
        bytesScanned = 0

        do {
            let start = Date()
            var nodes: [FileNode] = []
            var entriesScanned = 0
            var processed = 0
            var didHitBudget = false
            var reachedEnd = true
            let effectiveOffset = forceFullPass ? 0 : offset

            guard let enumerator = fileManager.enumerator(
                at: path,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                errorHandler: { url, error in
                    debugError("SwiftScanner: failed to enumerate \(url.path)", error: error)
                    return true
                }
            ) else {
                debugLog("SwiftScanner: failed to enumerate \(path.path)", category: "SCAN")
                return ScanDirectoryResult(nodes: [], isComplete: true, nextOffset: offset)
            }

            for case let url as URL in enumerator {
                entriesScanned += 1
                if entriesScanned <= effectiveOffset {
                    continue
                }

                if !forceFullPass {
                    if processed >= maxEntriesPerPass || Date().timeIntervalSince(start) > scanTimeBudget {
                        didHitBudget = true
                        reachedEnd = false
                        break
                    }
                }

                if let node = await scanItem(at: url) {
                    nodes.append(node)
                    reportProgress(path: url.path, size: node.size)
                }
                processed += 1
            }

            let sorted = nodes.sorted { $0.size > $1.size }
            let nextOffset = effectiveOffset + processed
            debugLog(
                "SwiftScanner: scanned \(processed) entries (offset \(effectiveOffset)) in \(path.path), complete=\(!didHitBudget && reachedEnd), forceFullPass=\(forceFullPass)",
                category: "SCAN"
            )
            return ScanDirectoryResult(nodes: sorted, isComplete: !didHitBudget && reachedEnd, nextOffset: nextOffset)

        } catch {
            debugLog("SwiftScanner error scanning \(path.path): \(error)", category: "SCAN")
            return ScanDirectoryResult(nodes: [], isComplete: true, nextOffset: offset)
        }
    }

    /// Scan a single item - quick scan without recursive size calculation
    /// For "heavy" directories like node_modules, uses `du` for fast size calculation
    private func scanItem(at url: URL) async -> FileNode? {
        do {
            let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

            let isDirectory = resourceValues.isDirectory ?? false
            let isSymlink = resourceValues.isSymbolicLink ?? false
            let modifiedDate = resourceValues.contentModificationDate

            var node = FileNode(
                path: url,
                name: url.lastPathComponent,
                size: 0,
                isDirectory: isDirectory
            )
            node.modifiedDate = modifiedDate
            node.isSymlink = isSymlink
            node.fileType = classifyFileType(url: url, isDirectory: isDirectory)
            node.scanStatus = isDirectory ? .scanning : .current // Mark directories as partial until fully scanned

            if isSymlink {
                // For symlinks, get the target but don't follow for size
                node.symlinkTarget = try? fileManager.destinationOfSymbolicLink(atPath: url.path)
                node.size = metadataEstimatedSize(from: resourceValues) ?? 0
                node.itemCount = 0
            } else if isDirectory {
                // Check if this is a "heavy" directory that should use fast sizing
                if isHeavyDirectory(url) {
                    debugLog("Fast sizing \(url.lastPathComponent) with du", category: "SCAN")
                    // Use du for fast recursive size
                    if let size = getDirectorySizeWithDu(url) {
                        node.size = size
                        node.scanStatus = .current  // Mark as fully scanned (don't recurse into it)
                        debugLog("Fast sized \(url.lastPathComponent): \(size) bytes", category: "SCAN")
                    } else {
                        node.size = 0
                    }
                    node.itemCount = countDirectoryItems(url)
                } else if let estimate = metadataEstimatedSize(from: resourceValues) {
                    // Regular directory - metadata-based estimate (non-recursive, fast)
                    node.size = estimate
                    node.itemCount = 0
                } else {
                    let estimate = sampleDirectoryEstimate(url)
                    // Fallback estimate based on quick sampling (not recursive)
                    node.itemCount = estimate.itemCount
                    node.size = estimate.size
                }
            } else {
                // File size
                node.size = metadataEstimatedSize(from: resourceValues) ?? 0
                node.itemCount = 0
            }

            return node

        } catch {
            // Permission denied or other error - still return a node with error status
            debugError("SwiftScanner: failed to read \(url.path)", error: error)
            var node = FileNode(
                path: url,
                name: url.lastPathComponent,
                size: 0,
                isDirectory: false
            )
            node.scanStatus = .error(error.localizedDescription)
            return node
        }
    }

    private func sampleDirectoryEstimate(_ url: URL) -> (size: Int64, itemCount: Int) {
        let start = Date()
        var count = 0
        var size: Int64 = 0
        var reachedEnd = true

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return (Int64(0), 0)
        }

        for case let childURL as URL in enumerator {
            count += 1
            if count > sampleEntryLimit || Date().timeIntervalSince(start) > sampleTimeBudget {
                reachedEnd = false
                break
            }

            if let values = try? childURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]) {
                let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0
                size += Int64(allocated)
            }
        }

        if reachedEnd {
            return (size, count)
        }

        let estimatedCount = count * 4
        let average = count > 0 ? (size / Int64(count)) : 0
        return (average * Int64(estimatedCount), estimatedCount)
    }

    private func metadataEstimatedSize(from values: URLResourceValues) -> Int64? {
        let size = values.totalFileAllocatedSize
            ?? values.totalFileSize
            ?? values.fileAllocatedSize
            ?? values.fileSize
            ?? 0
        guard size > 0 else { return nil }
        return Int64(size)
    }

    /// Calculate total size of a directory recursively
    private func calculateDirectorySize(at url: URL) async -> (size: Int64, count: Int) {
        var totalSize: Int64 = 0
        var itemCount = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true } // Continue on errors
        ) else {
            return (0, 0)
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey])

                if !(resourceValues.isDirectory ?? false) {
                    let size = Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0)
                    totalSize += size
                    itemCount += 1
                }
            } catch {
                // Skip files we can't read
                continue
            }
        }

        return (totalSize, itemCount)
    }

    /// Classify file type based on extension
    private func classifyFileType(url: URL, isDirectory: Bool) -> FileType {
        if isDirectory {
            let name = url.lastPathComponent.lowercased()
            // Check for known system/cache directories
            if name == "library" || name == "system" || name.hasPrefix(".") {
                return .system
            }
            if name == "caches" || name == "cache" {
                return .cache
            }
            if name == "applications" || name.hasSuffix(".app") {
                return .application
            }
            return .other
        }

        let ext = url.pathExtension.lowercased()

        // Video
        if ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"].contains(ext) {
            return .video
        }

        // Audio
        if ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"].contains(ext) {
            return .audio
        }

        // Images
        if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "raw", "svg"].contains(ext) {
            return .image
        }

        // Code
        if ["swift", "js", "ts", "py", "rb", "go", "rs", "c", "cpp", "h", "java", "kt", "cs", "php", "html", "css", "json", "xml", "yaml", "yml", "sh", "bash", "zsh"].contains(ext) {
            return .code
        }

        // Archives
        if ["zip", "tar", "gz", "rar", "7z", "dmg", "iso", "pkg"].contains(ext) {
            return .archive
        }

        // Applications
        if ["app", "exe", "dll", "so", "dylib"].contains(ext) {
            return .application
        }

        // Documents
        if ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key", "md"].contains(ext) {
            return .document
        }

        return .other
    }
}
