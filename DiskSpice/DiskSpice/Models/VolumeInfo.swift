import Foundation

struct VolumeInfo: Identifiable, Codable {
    let id: UUID
    let path: URL
    let name: String
    var totalSize: Int64
    var usedSize: Int64
    var freeSize: Int64
    var isExternal: Bool
    var rootNode: FileNode?

    var usedPercentage: Double {
        guard totalSize > 0 else { return 0 }
        return Double(usedSize) / Double(totalSize)
    }

    init(path: URL, name: String, totalSize: Int64, usedSize: Int64, isExternal: Bool = false) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.totalSize = totalSize
        self.usedSize = usedSize
        self.freeSize = totalSize - usedSize
        self.isExternal = isExternal
        self.rootNode = nil
    }
}
