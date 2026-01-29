import Foundation

/// A file destination that buffers log messages for efficient batch writes.
///
/// Reduces I/O overhead by accumulating messages and writing them in batches,
/// either when the buffer is full or at regular intervals.
public actor BufferedFileDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let fileURL: URL
    public nonisolated let batchSize: Int
    public nonisolated let flushInterval: TimeInterval

    private var buffer: [String] = []
    private var fileHandle: FileHandle?
    private var flushTask: Task<Void, Never>?
    private var lastFlush: Date = Date()
    private var isFlushTaskStarted: Bool = false
    private let dateFormatter: ISO8601DateFormatter

    /// Creates a buffered file destination.
    /// - Parameters:
    ///   - fileURL: The URL of the log file.
    ///   - minimumLevel: Minimum level to log (default: .trace).
    ///   - batchSize: Number of messages to buffer before writing (default: 100).
    ///   - flushInterval: Maximum seconds between flushes (default: 5.0).
    ///   - createDirectories: Whether to create parent directories if needed.
    /// - Throws: Error if the file cannot be created.
    public init(
        fileURL: URL,
        minimumLevel: LogLevel = .trace,
        batchSize: Int = 100,
        flushInterval: TimeInterval = 5.0,
        createDirectories: Bool = false
    ) throws {
        self.fileURL = fileURL
        self.minimumLevel = minimumLevel
        self.batchSize = max(1, batchSize)
        self.flushInterval = max(0.1, flushInterval)

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

        // Open file handle
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            throw FileDestinationError.failedToOpenFile(fileURL)
        }
        try handle.seekToEnd()
        self.fileHandle = handle
    }

    deinit {
        flushTask?.cancel()
        // Note: Can't call async flush in deinit, but Task will be cancelled
    }

    public func log(_ message: LogMessage) async {
        guard message.level >= minimumLevel else { return }

        // Start periodic flush task on first log
        if !isFlushTaskStarted {
            isFlushTaskStarted = true
            flushTask = Task { [weak self] in
                await self?.runPeriodicFlush()
            }
        }

        let line = format(message)
        buffer.append(line)

        if buffer.count >= batchSize {
            await flush()
        }
    }

    /// Flushes the buffer to disk immediately.
    public func flush() async {
        guard !buffer.isEmpty else { return }

        let lines = buffer.joined(separator: "\n") + "\n"
        buffer.removeAll(keepingCapacity: true)

        if let data = lines.data(using: .utf8) {
            try? fileHandle?.write(contentsOf: data)
            try? fileHandle?.synchronize()
        }

        lastFlush = Date()
    }

    /// Returns the current number of buffered messages.
    public func bufferedCount() -> Int {
        buffer.count
    }

    /// Closes the file handle and flushes remaining messages.
    public func close() async {
        flushTask?.cancel()
        await flush()
        try? fileHandle?.close()
        fileHandle = nil
    }

    // MARK: - Private

    private func format(_ message: LogMessage) -> String {
        let timestamp = dateFormatter.string(from: message.timestamp)
        let level = message.level.description.padding(toLength: 8, withPad: " ", startingAt: 0)
        var result = "\(timestamp) [\(level)] [\(message.source)] \(message.message)"

        if let metadata = message.metadata, !metadata.isEmpty {
            let metaStr = metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            result += " {\(metaStr)}"
        }

        return result
    }

    private func runPeriodicFlush() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else { break }

            let timeSinceFlush = Date().timeIntervalSince(lastFlush)
            let hasBuffer = !buffer.isEmpty

            if hasBuffer && timeSinceFlush >= flushInterval {
                await flush()
            }
        }
    }
}
