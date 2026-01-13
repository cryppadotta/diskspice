import Foundation
import AppKit

class FileOperations {

    /// Threshold size for showing confirmation (100 MB)
    static let confirmationThreshold: Int64 = 100_000_000

    /// Move a file or folder to Trash
    /// - Returns: The URL of the item in Trash
    @discardableResult
    static func moveToTrash(at url: URL) throws -> URL {
        if let recycledURL = try? recycleToTrash(url) {
            debugLog("Moved to Trash: \(recycledURL.path)", category: "FILE")
            return recycledURL
        }

        var trashedURL: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
        } catch {
            debugError("Failed to move item to Trash: \(url.path)", error: error)
            throw error
        }

        if let trashedURL = trashedURL as URL? {
            debugLog("Moved to Trash: \(trashedURL.path)", category: "FILE")
            return trashedURL
        }

        let originalExists = FileManager.default.fileExists(atPath: url.path)
        if originalExists {
            debugLog("Trash move failed, item still exists at \(url.path)", category: "FILE")
            throw FileOperationError.deletionFailed("Item still exists after move to Trash.")
        }

        debugLog("Move to Trash returned no URL for \(url.path)", category: "FILE")
        return url
    }

    static func moveToTrashAsync(at url: URL) async throws -> URL {
        do {
            let recycledURL = try await recycleToTrashAsync(url)
            debugLog("Moved to Trash: \(recycledURL.path)", category: "FILE")
            return recycledURL
        } catch {
            debugError("Recycle failed for \(url.path)", error: error)
        }

        let trashedURL = try await trashItemAsync(url)
        debugLog("Moved to Trash: \(trashedURL.path)", category: "FILE")
        return trashedURL
    }

    /// Move multiple items to Trash
    static func moveToTrash(urls: [URL]) throws {
        for url in urls {
            try moveToTrash(at: url)
        }
    }

    /// Check if item requires confirmation before deletion
    static func requiresConfirmation(_ node: FileNode) -> Bool {
        node.size >= confirmationThreshold
    }

    /// Show confirmation dialog for large file deletion
    /// - Returns: true if user confirms
    static func confirmDeletion(of node: FileNode) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "Are you sure you want to move \"\(node.name)\" (\(formatBytes(node.size))) to the Trash?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Reveal item in Finder
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open item with default application
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Get info (show in Finder info panel)
    static func getInfo(_ url: URL) {
        let script = "tell application \"Finder\" to open information window of (POSIX file \"\(url.path)\" as alias)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    /// Copy item path to clipboard
    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    // MARK: - Helpers

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func recycleToTrash(_ url: URL) throws -> URL {
        let semaphore = DispatchSemaphore(value: 0)
        var resultURL: URL?
        var resultError: Error?

        NSWorkspace.shared.recycle([url]) { urls, error in
            resultURL = urls[url] ?? urls.values.first
            resultError = error
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 5)

        if let error = resultError {
            debugError("Recycle failed for \(url.path)", error: error)
            throw error
        }

        guard let resultURL else {
            throw FileOperationError.deletionFailed("Recycle returned no Trash URL.")
        }

        return resultURL
    }

    private static func recycleToTrashAsync(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { urls, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let resultURL = urls[url] ?? urls.values.first {
                    continuation.resume(returning: resultURL)
                } else {
                    continuation.resume(throwing: FileOperationError.deletionFailed("Recycle returned no Trash URL."))
                }
            }
        }
    }

    private static func trashItemAsync(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var trashedURL: NSURL?
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                    if let trashedURL = trashedURL as URL? {
                        continuation.resume(returning: trashedURL)
                    } else {
                        let originalExists = FileManager.default.fileExists(atPath: url.path)
                        if originalExists {
                            continuation.resume(throwing: FileOperationError.deletionFailed("Item still exists after move to Trash."))
                        } else {
                            continuation.resume(throwing: FileOperationError.deletionFailed("Move to Trash returned no URL."))
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - File Operation Errors

enum FileOperationError: Error, LocalizedError {
    case permissionDenied
    case itemNotFound
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied. You may need to grant Full Disk Access in System Preferences."
        case .itemNotFound:
            return "The item could not be found."
        case .deletionFailed(let message):
            return "Deletion failed: \(message)"
        }
    }
}
