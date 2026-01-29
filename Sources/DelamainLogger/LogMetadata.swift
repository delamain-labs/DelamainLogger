import Foundation

/// A type-safe value for structured logging metadata.
///
/// Supports common types and nested structures for rich log context.
public enum LogMetadataValue: Sendable, Equatable, CustomStringConvertible {
    /// A string value.
    case string(String)
    /// An integer value.
    case int(Int)
    /// A floating-point value.
    case double(Double)
    /// A boolean value.
    case bool(Bool)
    /// A nested dictionary of metadata.
    case dictionary([String: LogMetadataValue])
    /// An array of metadata values.
    case array([LogMetadataValue])
    /// A null/nil value.
    case null

    public var description: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .dictionary(let dict):
            let pairs = dict.map { "\($0.key)=\($0.value)" }
            return "[\(pairs.joined(separator: ", "))]"
        case .array(let arr):
            return "[\(arr.map(\.description).joined(separator: ", "))]"
        case .null:
            return "null"
        }
    }

    /// Converts the value to a JSON-compatible representation.
    public var jsonValue: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .dictionary(let dict):
            return dict.mapValues { $0.jsonValue }
        case .array(let arr):
            return arr.map { $0.jsonValue }
        case .null:
            return NSNull()
        }
    }
}

// MARK: - ExpressibleBy Literals

extension LogMetadataValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension LogMetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension LogMetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension LogMetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension LogMetadataValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, LogMetadataValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension LogMetadataValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: LogMetadataValue...) {
        self = .array(elements)
    }
}

extension LogMetadataValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

// MARK: - Type Alias

/// A dictionary of metadata key-value pairs for structured logging.
public typealias LogMetadata = [String: LogMetadataValue]

// MARK: - Codable Support

extension LogMetadataValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([LogMetadataValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: LogMetadataValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.typeMismatch(
                LogMetadataValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported type for LogMetadataValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let dict):
            try container.encode(dict)
        case .array(let arr):
            try container.encode(arr)
        case .null:
            try container.encodeNil()
        }
    }
}
