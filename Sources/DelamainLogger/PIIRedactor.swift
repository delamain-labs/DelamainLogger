import Foundation

/// A pattern for detecting and redacting PII.
public struct PIIPattern: Sendable {
    /// Name of the PII type (e.g., "email", "ssn").
    public let name: String

    /// Regex pattern to match.
    public let pattern: String

    /// Replacement text (use $1, $2 for capture groups).
    public let replacement: String

    /// Creates a PII pattern.
    public init(name: String, pattern: String, replacement: String = "[REDACTED]") {
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
    }
}

// MARK: - Built-in Patterns

extension PIIPattern {
    /// Email addresses.
    public static let email = PIIPattern(
        name: "email",
        pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
        replacement: "[EMAIL]"
    )

    /// Phone numbers (various formats).
    public static let phone = PIIPattern(
        name: "phone",
        pattern: #"(\+?1?[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#,
        replacement: "[PHONE]"
    )

    /// Social Security Numbers.
    public static let ssn = PIIPattern(
        name: "ssn",
        pattern: #"\d{3}[-\s]?\d{2}[-\s]?\d{4}"#,
        replacement: "[SSN]"
    )

    /// Credit card numbers (basic pattern).
    public static let creditCard = PIIPattern(
        name: "creditCard",
        pattern: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#,
        replacement: "[CARD]"
    )

    /// IP addresses (IPv4).
    public static let ipAddress = PIIPattern(
        name: "ipAddress",
        pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
        replacement: "[IP]"
    )

    /// Bearer tokens and API keys.
    public static let bearerToken = PIIPattern(
        name: "bearerToken",
        pattern: #"(?i)bearer\s+[a-zA-Z0-9._-]+"#,
        replacement: "[TOKEN]"
    )

    /// Generic API keys (common patterns).
    public static let apiKey = PIIPattern(
        name: "apiKey",
        pattern: #"(?i)(api[_-]?key|apikey|api_secret|access_token)[\"']?\s*[:=]\s*[\"']?[a-zA-Z0-9._-]{16,}[\"']?"#,
        replacement: "$1=[REDACTED]"
    )

    /// JWT tokens.
    public static let jwt = PIIPattern(
        name: "jwt",
        pattern: #"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*"#,
        replacement: "[JWT]"
    )

    /// Passwords in key-value format.
    public static let password = PIIPattern(
        name: "password",
        pattern: #"(?i)(password|passwd|pwd)[\"']?\s*[:=]\s*[\"']?[^\s\"']+[\"']?"#,
        replacement: "$1=[REDACTED]"
    )

    /// All built-in patterns.
    public static let all: [PIIPattern] = [
        .email, .phone, .ssn, .creditCard, .ipAddress,
        .bearerToken, .apiKey, .jwt, .password
    ]

    /// Common patterns (email, phone, SSN, credit card).
    public static let common: [PIIPattern] = [
        .email, .phone, .ssn, .creditCard
    ]

    /// Security-focused patterns (tokens, keys, passwords).
    public static let security: [PIIPattern] = [
        .bearerToken, .apiKey, .jwt, .password
    ]
}

// MARK: - Redactor

/// Redacts PII from strings based on configured patterns.
public struct PIIRedactor: Sendable {
    /// Patterns to apply for redaction.
    public let patterns: [PIIPattern]

    /// Compiled regex patterns for performance.
    private let compiledPatterns: [(PIIPattern, NSRegularExpression)]

    /// Creates a PII redactor with specified patterns.
    /// - Parameter patterns: Patterns to use for redaction.
    public init(patterns: [PIIPattern] = PIIPattern.common) {
        self.patterns = patterns
        self.compiledPatterns = patterns.compactMap { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern.pattern, options: []) else {
                return nil
            }
            return (pattern, regex)
        }
    }

    /// Redacts PII from a string.
    /// - Parameter string: The input string.
    /// - Returns: String with PII redacted.
    public func redact(_ string: String) -> String {
        var result = string

        for (pattern, regex) in compiledPatterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: pattern.replacement
            )
        }

        return result
    }

    /// Redacts PII from log metadata.
    /// - Parameter metadata: The metadata dictionary.
    /// - Returns: Metadata with PII redacted from values.
    public func redact(_ metadata: LogMetadata?) -> LogMetadata? {
        guard let metadata else { return nil }

        return metadata.mapValues { value in
            redactValue(value)
        }
    }

    private func redactValue(_ value: LogMetadataValue) -> LogMetadataValue {
        switch value {
        case .string(let str):
            return .string(redact(str))
        case .dictionary(let dict):
            return .dictionary(dict.mapValues { redactValue($0) })
        case .array(let arr):
            return .array(arr.map { redactValue($0) })
        default:
            return value
        }
    }

    /// Redacts PII from a log message, returning a new message.
    /// - Parameter message: The original log message.
    /// - Returns: A new log message with PII redacted.
    public func redact(_ message: LogMessage) -> LogMessage {
        LogMessage(
            level: message.level,
            message: redact(message.message),
            metadata: redact(message.metadata),
            source: message.source,
            file: message.file,
            function: message.function,
            line: message.line,
            timestamp: message.timestamp
        )
    }
}

// MARK: - Redacting Destination Wrapper

/// A destination wrapper that redacts PII before forwarding to another destination.
public actor RedactingDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel

    private let wrapped: any LogDestination
    private let redactor: PIIRedactor

    /// Creates a redacting destination.
    /// - Parameters:
    ///   - destination: The destination to wrap.
    ///   - redactor: The PII redactor to use.
    public init(
        wrapping destination: any LogDestination,
        redactor: PIIRedactor = PIIRedactor()
    ) {
        self.wrapped = destination
        self.minimumLevel = destination.minimumLevel
        self.redactor = redactor
    }

    public func log(_ message: LogMessage) async {
        let redactedMessage = redactor.redact(message)
        await wrapped.log(redactedMessage)
    }
}

// MARK: - Logger Extension

extension Logger {
    /// Adds a destination wrapped with PII redaction.
    /// - Parameters:
    ///   - destination: The destination to add.
    ///   - redactor: The PII redactor to use.
    public func addRedactingDestination(
        _ destination: any LogDestination,
        redactor: PIIRedactor = PIIRedactor()
    ) async {
        let redacting = RedactingDestination(wrapping: destination, redactor: redactor)
        await addDestination(redacting)
    }
}
