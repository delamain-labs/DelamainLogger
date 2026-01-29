import Foundation

/// A filter that determines whether a log message should be processed.
///
/// Filters can be combined using logical operators for complex filtering rules.
public protocol LogFilter: Sendable {
    /// Determines if the given log message should pass through the filter.
    /// - Parameter message: The log message to evaluate.
    /// - Returns: `true` if the message should be logged, `false` to filter it out.
    func shouldLog(_ message: LogMessage) -> Bool
}

// MARK: - Built-in Filters

/// Filters messages by minimum log level.
public struct LevelFilter: LogFilter {
    /// The minimum level required to pass the filter.
    public let minimumLevel: LogLevel

    /// Creates a level filter.
    /// - Parameter minimumLevel: Messages below this level are filtered out.
    public init(minimumLevel: LogLevel) {
        self.minimumLevel = minimumLevel
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        message.level >= minimumLevel
    }
}

/// Filters messages by source/category.
public struct SourceFilter: LogFilter {
    /// The sources to include (if set) or exclude.
    public let sources: Set<String>

    /// If true, include only matching sources. If false, exclude matching sources.
    public let include: Bool

    /// Creates a source filter.
    /// - Parameters:
    ///   - sources: The source identifiers to match.
    ///   - include: If true, only matching sources pass. If false, matching sources are excluded.
    public init(sources: Set<String>, include: Bool = true) {
        self.sources = sources
        self.include = include
    }

    /// Convenience initializer for including specific sources.
    public static func include(_ sources: String...) -> SourceFilter {
        SourceFilter(sources: Set(sources), include: true)
    }

    /// Convenience initializer for excluding specific sources.
    public static func exclude(_ sources: String...) -> SourceFilter {
        SourceFilter(sources: Set(sources), include: false)
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        let matches = sources.contains(message.source)
        return include ? matches : !matches
    }
}

/// Filters messages by message content.
public struct MessageFilter: LogFilter {
    /// The predicate to match against message text.
    public let predicate: @Sendable (String) -> Bool

    /// Creates a message content filter.
    /// - Parameter predicate: A closure that returns true if the message should pass.
    public init(predicate: @escaping @Sendable (String) -> Bool) {
        self.predicate = predicate
    }

    /// Creates a filter that passes messages containing the given substring.
    public static func contains(_ substring: String, caseSensitive: Bool = true) -> MessageFilter {
        MessageFilter { message in
            if caseSensitive {
                return message.contains(substring)
            } else {
                return message.localizedCaseInsensitiveContains(substring)
            }
        }
    }

    /// Creates a filter that passes messages matching the given regex pattern.
    public static func matches(pattern: String) -> MessageFilter {
        MessageFilter { message in
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(message.startIndex..., in: message)
            return regex.firstMatch(in: message, range: range) != nil
        }
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        predicate(message.message)
    }
}

/// Filters messages by metadata keys or values.
public struct MetadataFilter: LogFilter {
    /// The predicate to evaluate against metadata.
    public let predicate: @Sendable (LogMetadata?) -> Bool

    /// Creates a metadata filter.
    /// - Parameter predicate: A closure that returns true if the metadata passes.
    public init(predicate: @escaping @Sendable (LogMetadata?) -> Bool) {
        self.predicate = predicate
    }

    /// Creates a filter that passes messages containing the specified metadata key.
    public static func hasKey(_ key: String) -> MetadataFilter {
        MetadataFilter { metadata in
            metadata?[key] != nil
        }
    }

    /// Creates a filter that passes messages where the metadata key equals the value.
    public static func equals(key: String, value: LogMetadataValue) -> MetadataFilter {
        MetadataFilter { metadata in
            metadata?[key] == value
        }
    }

    /// Creates a filter that passes messages with any of the specified keys.
    public static func hasAnyKey(_ keys: String...) -> MetadataFilter {
        MetadataFilter { metadata in
            guard let metadata else { return false }
            return keys.contains { metadata[$0] != nil }
        }
    }

    /// Creates a filter that passes messages with all of the specified keys.
    public static func hasAllKeys(_ keys: String...) -> MetadataFilter {
        MetadataFilter { metadata in
            guard let metadata else { return false }
            return keys.allSatisfy { metadata[$0] != nil }
        }
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        predicate(message.metadata)
    }
}

// MARK: - Filter Combinators

/// A filter that combines multiple filters with logical AND.
public struct AllOfFilter: LogFilter {
    /// The filters that must all pass.
    public let filters: [any LogFilter]

    /// Creates an AND filter.
    /// - Parameter filters: All filters must return true for the message to pass.
    public init(_ filters: [any LogFilter]) {
        self.filters = filters
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        filters.allSatisfy { $0.shouldLog(message) }
    }
}

/// A filter that combines multiple filters with logical OR.
public struct AnyOfFilter: LogFilter {
    /// The filters where at least one must pass.
    public let filters: [any LogFilter]

    /// Creates an OR filter.
    /// - Parameter filters: At least one filter must return true for the message to pass.
    public init(_ filters: [any LogFilter]) {
        self.filters = filters
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        filters.contains { $0.shouldLog(message) }
    }
}

/// A filter that negates another filter.
public struct NotFilter: LogFilter {
    /// The filter to negate.
    public let filter: any LogFilter

    /// Creates a NOT filter.
    /// - Parameter filter: The filter whose result will be inverted.
    public init(_ filter: any LogFilter) {
        self.filter = filter
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        !filter.shouldLog(message)
    }
}

// MARK: - Filter Builder DSL

/// A filter that always passes.
public struct PassFilter: LogFilter {
    public init() {}

    public func shouldLog(_ message: LogMessage) -> Bool {
        true
    }
}

/// A filter that always blocks.
public struct BlockFilter: LogFilter {
    public init() {}

    public func shouldLog(_ message: LogMessage) -> Bool {
        false
    }
}

// MARK: - Operator Extensions

extension LogFilter {
    /// Combines this filter with another using logical AND.
    public func and(_ other: any LogFilter) -> AllOfFilter {
        AllOfFilter([self, other])
    }

    /// Combines this filter with another using logical OR.
    public func or(_ other: any LogFilter) -> AnyOfFilter {
        AnyOfFilter([self, other])
    }

    /// Negates this filter.
    public var not: NotFilter {
        NotFilter(self)
    }
}
