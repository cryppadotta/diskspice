import Foundation

/// Debug logger that writes to a file for runtime debugging
/// Logs are written to: ~/Library/Logs/DiskSpice/debug.log
class DebugLogger {
    static let shared = DebugLogger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.diskspice.logger", qos: .utility)
    private var fileHandle: FileHandle?

    /// Whether logging is enabled (set to false in production)
    var isEnabled = true

    private init() {
        // Create log directory
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiskSpice")

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        logFileURL = logsDir.appendingPathComponent("debug.log")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Clear previous log on startup
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)

        // Open file handle for appending
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            fileHandle = try? FileHandle(forWritingTo: logFileURL)
            fileHandle?.seekToEndOfFile()
        }

        log("=== DiskSpice Debug Log Started ===", category: "SYSTEM")
        log("Log file: \(logFileURL.path)", category: "SYSTEM")
    }

    deinit {
        try? fileHandle?.close()
    }

    /// Log a message with a category tag
    func log(_ message: String, category: String = "DEBUG", file: String = #file, line: Int = #line) {
        guard isEnabled else { return }

        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let logLine = "[\(timestamp)] [\(category)] [\(fileName):\(line)] \(message)\n"

        queue.async { [weak self] in
            guard let self = self, let data = logLine.data(using: .utf8) else { return }
            self.fileHandle?.write(data)

            // Also print to console for Xcode debugging
            print(logLine, terminator: "")
        }
    }

    /// Log with context data (for inspecting values)
    func log(_ message: String, data: [String: Any], category: String = "DEBUG", file: String = #file, line: Int = #line) {
        let dataStr = data.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        log("\(message)\n\(dataStr)", category: category, file: file, line: line)
    }

    /// Log an error
    func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        var msg = message
        if let error = error {
            msg += " | Error: \(error.localizedDescription)"
        }
        log(msg, category: "ERROR", file: file, line: line)
    }

    /// Flush logs to disk
    func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }
}

// MARK: - Convenience Global Function

func debugLog(_ message: String, category: String = "DEBUG", file: String = #file, line: Int = #line) {
    DebugLogger.shared.log(message, category: category, file: file, line: line)
}

func debugLog(_ message: String, data: [String: Any], category: String = "DEBUG", file: String = #file, line: Int = #line) {
    DebugLogger.shared.log(message, data: data, category: category, file: file, line: line)
}

func debugError(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
    DebugLogger.shared.error(message, error: error, file: file, line: line)
}
