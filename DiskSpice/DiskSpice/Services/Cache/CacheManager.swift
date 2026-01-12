import Foundation

actor CacheManager {
    static let shared = CacheManager()

    private var loadedCaches: [String: CacheFile] = [:]

    // MARK: - Save

    /// Save scan results for a volume
    func save(nodes: [FileNode], for volume: VolumeInfo) async throws {
        try CachePaths.ensureCacheDirectoryExists()

        let entries = nodes.map { CacheEntry(from: $0) }
        let cacheFile = CacheFile(
            volumePath: volume.path.path,
            volumeName: volume.name,
            entries: entries
        )

        let fileURL = CachePaths.cacheFile(for: volume.path)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(cacheFile)
        try data.write(to: fileURL, options: .atomic)

        loadedCaches[volume.path.path] = cacheFile

        // Update index
        try await updateIndex()
    }

    /// Save tree from AppState
    func saveTree(_ tree: [URL: [FileNode]], for volume: VolumeInfo) async throws {
        try CachePaths.ensureCacheDirectoryExists()

        // Flatten tree to entries
        var allEntries: [CacheEntry] = []
        for (_, children) in tree {
            for node in children {
                allEntries.append(CacheEntry(from: node))
            }
        }

        let cacheFile = CacheFile(
            volumePath: volume.path.path,
            volumeName: volume.name,
            entries: allEntries
        )

        let fileURL = CachePaths.cacheFile(for: volume.path)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(cacheFile)
        try data.write(to: fileURL, options: .atomic)

        loadedCaches[volume.path.path] = cacheFile
        try await updateIndex()
    }

    // MARK: - Load

    /// Load cached data for a volume
    func load(for volumePath: URL) async throws -> [FileNode]? {
        // Check memory cache first
        if let cached = loadedCaches[volumePath.path] {
            return cached.entries.map { $0.toFileNode() }
        }

        let fileURL = CachePaths.cacheFile(for: volumePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let cacheFile = try decoder.decode(CacheFile.self, from: data)

        // Check version compatibility
        guard cacheFile.isCompatible else {
            // Incompatible version, delete and return nil
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        loadedCaches[volumePath.path] = cacheFile
        return cacheFile.entries.map { $0.toFileNode() }
    }

    /// Load all cached volumes
    func loadIndex() async throws -> CacheIndex? {
        let fileURL = CachePaths.indexFile

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(CacheIndex.self, from: data)
    }

    // MARK: - Clear

    /// Clear cache for a specific volume
    func clear(for volumePath: URL) async throws {
        let fileURL = CachePaths.cacheFile(for: volumePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        loadedCaches.removeValue(forKey: volumePath.path)
        try await updateIndex()
    }

    /// Clear all cache
    func clearAll() async throws {
        if FileManager.default.fileExists(atPath: CachePaths.cacheDirectory.path) {
            try FileManager.default.removeItem(at: CachePaths.cacheDirectory)
        }
        loadedCaches.removeAll()
    }

    // MARK: - Private

    private func updateIndex() async throws {
        var volumes: [CacheIndex.CacheVolumeIndex] = []

        let contents = try? FileManager.default.contentsOfDirectory(
            at: CachePaths.cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )

        for url in contents ?? [] {
            guard url.pathExtension == "json", url.lastPathComponent != "index.json" else { continue }

            if let data = try? Data(contentsOf: url),
               let cacheFile = try? JSONDecoder().decode(CacheFile.self, from: data) {
                volumes.append(CacheIndex.CacheVolumeIndex(
                    path: cacheFile.volumePath,
                    name: cacheFile.volumeName,
                    totalSize: 0,  // Would need to be stored separately
                    usedSize: cacheFile.entries.reduce(0) { $0 + $1.size },
                    cacheFile: url.lastPathComponent,
                    lastUpdated: cacheFile.updatedAt,
                    entryCount: cacheFile.entries.count
                ))
            }
        }

        let index = CacheIndex(version: CacheVersion.current, volumes: volumes)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(index)
        try data.write(to: CachePaths.indexFile, options: .atomic)
    }
}
