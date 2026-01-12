import Foundation

enum FileType: String, Codable, CaseIterable {
    case video, audio, image
    case code, archive, application
    case system, cache, document
    case other

    var color: String {
        switch self {
        case .video: return "blue"
        case .audio: return "purple"
        case .image: return "green"
        case .code: return "orange"
        case .archive: return "brown"
        case .application: return "red"
        case .system: return "gray"
        case .cache: return "yellow"
        case .document: return "teal"
        case .other: return "secondary"
        }
    }
}

enum ScanStatus: Codable, Equatable {
    case stale
    case scanning
    case current
    case error(String)
}

struct FileNode: Identifiable, Codable, Equatable {
    let id: UUID
    let path: URL
    let name: String
    var size: Int64
    var itemCount: Int
    var modifiedDate: Date?
    var isDirectory: Bool
    var isSymlink: Bool
    var symlinkTarget: String?
    var children: [FileNode]?
    var fileType: FileType
    var scanStatus: ScanStatus
    var lastScanned: Date?

    /// Size excluding symlinks (for parent total calculations)
    var effectiveSize: Int64 {
        isSymlink ? 0 : size
    }

    init(path: URL, name: String, size: Int64 = 0, isDirectory: Bool = false) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.size = size
        self.itemCount = 0
        self.modifiedDate = nil
        self.isDirectory = isDirectory
        self.isSymlink = false
        self.symlinkTarget = nil
        self.children = isDirectory ? [] : nil
        self.fileType = .other
        self.scanStatus = .stale
        self.lastScanned = nil
    }
}
