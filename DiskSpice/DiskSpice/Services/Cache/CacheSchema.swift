import Foundation

// MARK: - Cache Version

struct CacheVersion {
    static let current = 1
}

// MARK: - Cache Entry

/// Represents a single cached file/folder entry
struct CacheEntry: Codable {
    let path: String
    let parentPath: String?
    let name: String
    let size: Int64
    let isDirectory: Bool
    let isSymlink: Bool
    let symlinkTarget: String?
    let fileType: String
    let itemCount: Int
    let modifiedDate: Date?
    let lastScanned: Date
    let scanStatus: String
    let childPaths: [String]?

    init(from node: FileNode, parentPath: URL? = nil) {
        self.path = node.path.path
        self.parentPath = parentPath?.path
        self.name = node.name
        self.size = node.size
        self.isDirectory = node.isDirectory
        self.isSymlink = node.isSymlink
        self.symlinkTarget = node.symlinkTarget
        self.fileType = node.fileType.rawValue
        self.itemCount = node.itemCount
        self.modifiedDate = node.modifiedDate
        self.lastScanned = node.lastScanned ?? Date()
        self.scanStatus = Self.statusToString(node.scanStatus)
        self.childPaths = nil
    }

    func toFileNode() -> FileNode {
        var node = FileNode(
            path: URL(fileURLWithPath: path),
            name: name,
            size: size,
            isDirectory: isDirectory
        )
        node.isSymlink = isSymlink
        node.symlinkTarget = symlinkTarget
        node.fileType = FileType(rawValue: fileType) ?? .other
        node.itemCount = itemCount
        node.modifiedDate = modifiedDate
        node.lastScanned = lastScanned
        node.scanStatus = Self.stringToStatus(scanStatus)
        return node
    }

    private static func statusToString(_ status: ScanStatus) -> String {
        switch status {
        case .stale: return "stale"
        case .scanning: return "scanning"
        case .current: return "current"
        case .error(let msg): return "error:\(msg)"
        }
    }

    private static func stringToStatus(_ string: String) -> ScanStatus {
        if string == "stale" { return .stale }
        if string == "scanning" { return .scanning }
        if string == "current" { return .current }
        if string.hasPrefix("error:") {
            return .error(String(string.dropFirst(6)))
        }
        return .stale
    }
}

// MARK: - Cache File

/// The root cache file structure
struct CacheFile: Codable {
    let version: Int
    let createdAt: Date
    let updatedAt: Date
    let volumePath: String
    let volumeName: String
    let entries: [CacheEntry]

    init(volumePath: String, volumeName: String, entries: [CacheEntry]) {
        self.version = CacheVersion.current
        self.createdAt = Date()
        self.updatedAt = Date()
        self.volumePath = volumePath
        self.volumeName = volumeName
        self.entries = entries
    }

    /// Check if cache is compatible with current version
    var isCompatible: Bool {
        version == CacheVersion.current
    }
}

// MARK: - Cache Index

/// Index file for quick lookups without loading full cache
struct CacheIndex: Codable {
    let version: Int
    let volumes: [CacheVolumeIndex]

    struct CacheVolumeIndex: Codable {
        let path: String
        let name: String
        let totalSize: Int64
        let usedSize: Int64
        let cacheFile: String
        let lastUpdated: Date
        let entryCount: Int
    }
}

// MARK: - Cache Paths

struct CachePaths {
    static var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DiskSpice/Cache", isDirectory: true)
    }

    static var indexFile: URL {
        cacheDirectory.appendingPathComponent("index.json")
    }

    static func cacheFile(for volumePath: URL) -> URL {
        let safeName = volumePath.path.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent("volume_\(safeName).json")
    }

    static func ensureCacheDirectoryExists() throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
