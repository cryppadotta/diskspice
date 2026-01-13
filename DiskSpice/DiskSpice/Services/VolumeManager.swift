import Foundation
import AppKit

class VolumeManager {
    private static let resourceKeys: [URLResourceKey] = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeIsRemovableKey,
        .volumeIsEjectableKey,
        .volumeIsLocalKey,
        .volumeIsInternalKey
    ]

    /// Discover all mounted volumes
    static func discoverVolumes() -> [VolumeInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { url -> VolumeInfo? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                let name = resourceValues.volumeName ?? url.lastPathComponent
                let totalSize = Int64(resourceValues.volumeTotalCapacity ?? 0)
                let freeSize: Int64
                if let important = resourceValues.volumeAvailableCapacityForImportantUsage {
                    freeSize = important
                } else {
                    freeSize = Int64(resourceValues.volumeAvailableCapacity ?? 0)
                }
                let usedSize = totalSize - freeSize

                // Skip volumes with no size (virtual volumes)
                guard totalSize > 0 else { return nil }

                // Determine if external
                let isExternal = !(resourceValues.volumeIsInternal ?? true)
                    || (resourceValues.volumeIsRemovable ?? false)
                    || (resourceValues.volumeIsEjectable ?? false)

                return VolumeInfo(
                    path: url,
                    name: name,
                    totalSize: totalSize,
                    usedSize: usedSize,
                    isExternal: isExternal
                )
            } catch {
                print("Error reading volume info for \(url.path): \(error)")
                return nil
            }
        }
    }

    /// Refresh info for a specific volume
    static func refreshVolumeInfo(_ volume: VolumeInfo) -> VolumeInfo? {
        do {
            let resourceValues = try volume.path.resourceValues(forKeys: Set(resourceKeys))

            let totalSize = Int64(resourceValues.volumeTotalCapacity ?? 0)
            let freeSize: Int64
            if let important = resourceValues.volumeAvailableCapacityForImportantUsage {
                freeSize = important
            } else {
                freeSize = Int64(resourceValues.volumeAvailableCapacity ?? 0)
            }
            let usedSize = totalSize - freeSize

            return VolumeInfo(
                path: volume.path,
                name: volume.name,
                totalSize: totalSize,
                usedSize: usedSize,
                isExternal: volume.isExternal
            )
        } catch {
            return nil
        }
    }

    /// Watch for volume mount/unmount events
    static func watchVolumeChanges(onChange: @escaping ([VolumeInfo]) -> Void) -> Any {
        // Use DistributedNotificationCenter to watch for volume changes
        let center = NSWorkspace.shared.notificationCenter

        let mountObserver = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { _ in
            onChange(discoverVolumes())
        }

        let unmountObserver = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { _ in
            onChange(discoverVolumes())
        }

        // Return both observers for cleanup
        return [mountObserver, unmountObserver]
    }

    /// Stop watching volume changes
    static func stopWatching(_ observers: Any) {
        guard let observerArray = observers as? [Any] else { return }
        let center = NSWorkspace.shared.notificationCenter
        for observer in observerArray {
            center.removeObserver(observer)
        }
    }
}
