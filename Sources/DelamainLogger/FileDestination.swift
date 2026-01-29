import Foundation

/// Error types for file destination operations.
public enum FileDestinationError: Error, Sendable {
    case failedToCreateFile(URL)
    case failedToCreateDirectory(URL)
    case failedToOpenFile(URL)
    case writeError(Error)
}

/// A log destination that writes to a file.
///
/// Supports file rotation by size and maintains backup copies.
public actor FileDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let fileURL: URL
    public nonisolated let maxFileSize: Int?
    public nonisolated let maxBackupCount: Int

    /// Optional filter for this destination.
    public let filter: (any LogFilter)?

    private var fileHandle: FileHandle?
    private var currentFileSize: Int = 0
    private let dateFormatter: ISO8601DateFormatter

    /// Creates a file destination.
    /// - Parameters:
    ///   - fileURL: The URL of the log file.
    ///   - minimumLevel: Minimum level to log (default: .trace).
    ///   - createDirectories: Whether to create parent directories if needed.
    ///   - maxFileSize: Maximum file size before rotation (nil = no rotation).
    ///   - maxBackupCount: Number of backup files to keep (default: 3).
    ///   - filter: Optional filter for this destination.
    /// - Throws: `FileDestinationError` if the file cannot be created.
    public init(
        fileURL: URL,
        minimumLevel: LogLevel = .trace,
        createDirectories: Bool = false,
        maxFileSize: Int? = nil,
        maxBackupCount: Int = 3,
        filter: (any LogFilter)? = nil
    ) throws {
        self.fileURL = fileURL
        self.minimumLevel = minimumLevel
        self.maxFileSize = maxFileSize
        self.maxBackupCount = maxBackupCount
        self.filter = filter

        self.dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Create directory if needed
        let directory = fileURL.deletingLastPathComponent()
        if createDirectories {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        // Open file handle for writing
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            throw FileDestinationError.failedToOpenFile(fileURL)
        }

        // Seek to end for appending
        try handle.seekToEnd()

        self.fileHandle = handle
        self.currentFileSize = try FileManager.default.attributesOfItem(
            atPath: fileURL.path
        )[.size] as? Int ?? 0
    }

    deinit {
        try? fileHandle?.close()
    }

    public func log(_ message: LogMessage) async {
        // Filter by minimum level
        guard message.level >= minimumLevel else { return }

        let line = format(message) + "\n"
        guard let data = line.data(using: .utf8) else { return }

        // Check if we need to rotate
        if let maxSize = maxFileSize, currentFileSize + data.count > maxSize {
            await rotate()
        }

        do {
            try fileHandle?.write(contentsOf: data)
            currentFileSize += data.count
        } catch {
            // Silently fail - logging shouldn't crash the app
        }
    }

    /// Forces a flush of the file buffer to disk.
    public func flush() async {
        try? fileHandle?.synchronize()
    }

    // MARK: - Private

    private func format(_ message: LogMessage) -> String {
        let timestamp = dateFormatter.string(from: message.timestamp)
        let level = message.level.description.padding(toLength: 8, withPad: " ", startingAt: 0)
        var result = "\(timestamp) [\(level)] [\(message.source)] \(message.message)"

        if let metaStr = message.formattedMetadata() {
            result += " {\(metaStr)}"
        }

        return result
    }

    private func rotate() async {
        // Close current file
        try? fileHandle?.close()

        // Delete oldest backup if we're at max
        let oldestBackup = fileURL.appendingPathExtension("\(maxBackupCount)")
        try? FileManager.default.removeItem(at: oldestBackup)

        // Shift existing backups
        for i in stride(from: maxBackupCount - 1, through: 1, by: -1) {
            let older = fileURL.appendingPathExtension("\(i)")
            let newer = fileURL.appendingPathExtension("\(i + 1)")
            try? FileManager.default.moveItem(at: older, to: newer)
        }

        // Move current file to .1
        let backup = fileURL.appendingPathExtension("1")
        try? FileManager.default.moveItem(at: fileURL, to: backup)

        // Create new file
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: fileURL)
        currentFileSize = 0
    }
}
