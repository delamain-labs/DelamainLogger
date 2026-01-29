import Foundation

/// A structured log message with metadata and source location.
public struct LogMessage: Sendable {
    /// The severity level of this log message.
    public let level: LogLevel

    /// The main log message text.
    public let message: String

    /// Optional key-value metadata for structured logging.
    public let metadata: LogMetadata?

    /// The source/category of this log message.
    public let source: String

    /// The file where the log was called.
    public let file: String

    /// The function where the log was called.
    public let function: String

    /// The line number where the log was called.
    public let line: Int

    /// The timestamp when the log was created.
    public let timestamp: Date

    /// Creates a new log message.
    /// - Parameters:
    ///   - level: The severity level.
    ///   - message: The main message text.
    ///   - metadata: Optional key-value metadata.
    ///   - source: The source/category name.
    ///   - file: The source file (auto-captured).
    ///   - function: The function name (auto-captured).
    ///   - line: The line number (auto-captured).
    ///   - timestamp: The creation timestamp (defaults to now).
    public init(
        level: LogLevel,
        message: String,
        metadata: LogMetadata? = nil,
        source: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        timestamp: Date = Date()
    ) {
        self.level = level
        self.message = message
        self.metadata = metadata
        self.source = source
        self.file = file
        self.function = function
        self.line = line
        self.timestamp = timestamp
    }

    /// Creates a new log message with string-only metadata (convenience).
    /// - Parameters:
    ///   - level: The severity level.
    ///   - message: The main message text.
    ///   - stringMetadata: Simple string key-value metadata.
    ///   - source: The source/category name.
    ///   - file: The source file (auto-captured).
    ///   - function: The function name (auto-captured).
    ///   - line: The line number (auto-captured).
    ///   - timestamp: The creation timestamp (defaults to now).
    public init(
        level: LogLevel,
        message: String,
        stringMetadata: [String: String],
        source: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        timestamp: Date = Date()
    ) {
        self.level = level
        self.message = message
        self.metadata = stringMetadata.mapValues { .string($0) }
        self.source = source
        self.file = file
        self.function = function
        self.line = line
        self.timestamp = timestamp
    }
}

// MARK: - Metadata Formatting

extension LogMessage {
    /// Formats metadata as a simple key=value string for text output.
    /// - Returns: Formatted metadata string or nil if no metadata.
    public func formattedMetadata() -> String? {
        guard let metadata, !metadata.isEmpty else { return nil }

        let pairs = metadata.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.description)"
        }
        return pairs.joined(separator: ", ")
    }

    /// Formats metadata as a JSON object.
    /// - Returns: JSON string or nil if no metadata.
    public func jsonMetadata() -> String? {
        guard let metadata, !metadata.isEmpty else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let data = try? encoder.encode(metadata),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }
}
