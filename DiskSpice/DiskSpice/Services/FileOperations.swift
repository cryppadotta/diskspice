import Foundation
import AppKit

class FileOperations {

    /// Threshold size for showing confirmation (100 MB)
    static let confirmationThreshold: Int64 = 100_000_000

    /// Move a file or folder to Trash
    /// - Returns: The URL of the item in Trash
    @discardableResult
    static func moveToTrash(at url: URL) throws -> URL {
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
        return (trashedURL as URL?) ?? url
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
