import Foundation

/// Output format for console logs.
public enum ConsoleFormat: Sendable {
    /// Minimal output: level and message only.
    case compact
    /// Standard output with timestamp, level, source, and message.
    case standard
    /// Verbose output including file, function, and line.
    case verbose
    /// JSON-formatted output for machine parsing.
    case json
}

/// A log destination that outputs to the console (stdout/stderr).
public actor ConsoleDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let format: ConsoleFormat
    public nonisolated let useColors: Bool

    /// Optional filter for this destination.
    public let filter: (any LogFilter)?

    private let dateFormatter: ISO8601DateFormatter

    /// Creates a console destination.
    /// - Parameters:
    ///   - minimumLevel: Minimum level to log (default: .trace).
    ///   - format: Output format (default: .standard).
    ///   - useColors: Whether to use ANSI colors (default: false).
    ///   - filter: Optional filter for this destination.
    public init(
        minimumLevel: LogLevel = .trace,
        format: ConsoleFormat = .standard,
        useColors: Bool = false,
        filter: (any LogFilter)? = nil
    ) {
        self.minimumLevel = minimumLevel
        self.format = format
        self.useColors = useColors
        self.filter = filter
        self.dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func log(_ message: LogMessage) async {
        let formatted = await format(message)

        // Error and above go to stderr
        if message.level >= .error {
            fputs(formatted + "\n", stderr)
        } else {
            print(formatted)
        }
    }

    /// Formats a log message according to the configured format.
    /// - Parameter message: The message to format.
    /// - Returns: The formatted string.
    public func format(_ message: LogMessage) -> String {
        switch format {
        case .compact:
            return formatCompact(message)
        case .standard:
            return formatStandard(message)
        case .verbose:
            return formatVerbose(message)
        case .json:
            return formatJSON(message)
        }
    }

    // MARK: - Format Implementations

    private func formatCompact(_ message: LogMessage) -> String {
        let level = colorize(message.level.description, for: message.level)
        return "[\(level)] \(message.message)"
    }

    private func formatStandard(_ message: LogMessage) -> String {
        let timestamp = dateFormatter.string(from: message.timestamp)
        let level = colorize(
            message.level.description.padding(toLength: 8, withPad: " ", startingAt: 0),
            for: message.level
        )
        var result = "\(timestamp) [\(level)] [\(message.source)] \(message.message)"

        if let metaStr = message.formattedMetadata() {
            result += " {\(metaStr)}"
        }

        return result
    }

    private func formatVerbose(_ message: LogMessage) -> String {
        let timestamp = dateFormatter.string(from: message.timestamp)
        let level = colorize(
            message.level.description.padding(toLength: 8, withPad: " ", startingAt: 0),
            for: message.level
        )
        let filename = URL(fileURLWithPath: message.file).lastPathComponent

        var result = "\(timestamp) [\(level)] [\(message.source)] \(message.message)"
        result += " @ \(filename):\(message.line) \(message.function)"

        if let metaStr = message.formattedMetadata() {
            result += " {\(metaStr)}"
        }

        return result
    }

    private func formatJSON(_ message: LogMessage) -> String {
        var dict: [String: Any] = [
            "timestamp": dateFormatter.string(from: message.timestamp),
            "level": message.level.description,
            "source": message.source,
            "message": message.message,
            "file": URL(fileURLWithPath: message.file).lastPathComponent,
            "function": message.function,
            "line": message.line
        ]

        if let metadata = message.metadata {
            dict["metadata"] = metadata.mapValues { $0.jsonValue }
        }

        return serializeJSON(dict)
    }

    private func serializeJSON(_ dict: [String: Any]) -> String {
        var parts: [String] = []

        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            let valueStr = serializeJSONValue(value)
            parts.append("\"\(key)\":\(valueStr)")
        }

        return "{\(parts.joined(separator: ","))}"
    }

    private func serializeJSONValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return "\"\(escapeJSON(string))\""
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return "\(double)"
        case let bool as Bool:
            return bool ? "true" : "false"
        case is NSNull:
            return "null"
        case let dict as [String: Any]:
            let inner = dict.sorted { $0.key < $1.key }.map { k, v in
                "\"\(k)\":\(serializeJSONValue(v))"
            }.joined(separator: ",")
            return "{\(inner)}"
        case let arr as [Any]:
            let inner = arr.map { serializeJSONValue($0) }.joined(separator: ",")
            return "[\(inner)]"
        default:
            return "\"\(value)\""
        }
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Colors

    private func colorize(_ text: String, for level: LogLevel) -> String {
        guard useColors else { return text }

        let colorCode: String
        switch level {
        case .trace: colorCode = "37" // White
        case .debug: colorCode = "36" // Cyan
        case .info: colorCode = "32"  // Green
        case .warning: colorCode = "33" // Yellow
        case .error: colorCode = "31" // Red
        case .critical: colorCode = "35;1" // Magenta bold
        }

        return "\u{001B}[\(colorCode)m\(text)\u{001B}[0m"
    }
}
