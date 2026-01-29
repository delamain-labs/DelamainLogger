import XCTest
@testable import DelamainLogger

final class LogMetadataTests: XCTestCase {

    // MARK: - Value Types

    func testStringValue() {
        let value: LogMetadataValue = "test"
        XCTAssertEqual(value, .string("test"))
        XCTAssertEqual(value.description, "test")
    }

    func testIntValue() {
        let value: LogMetadataValue = 42
        XCTAssertEqual(value, .int(42))
        XCTAssertEqual(value.description, "42")
    }

    func testDoubleValue() {
        let value: LogMetadataValue = 3.14
        XCTAssertEqual(value, .double(3.14))
        XCTAssertTrue(value.description.hasPrefix("3.14"))
    }

    func testBoolValue() {
        let trueValue: LogMetadataValue = true
        let falseValue: LogMetadataValue = false
        XCTAssertEqual(trueValue, .bool(true))
        XCTAssertEqual(falseValue, .bool(false))
        XCTAssertEqual(trueValue.description, "true")
        XCTAssertEqual(falseValue.description, "false")
    }

    func testNullValue() {
        let value: LogMetadataValue = nil
        XCTAssertEqual(value, .null)
        XCTAssertEqual(value.description, "null")
    }

    func testArrayValue() {
        let value: LogMetadataValue = [1, 2, 3]
        if case .array(let arr) = value {
            XCTAssertEqual(arr.count, 3)
        } else {
            XCTFail("Expected array value")
        }
    }

    func testDictionaryValue() {
        let value: LogMetadataValue = ["key": "value"]
        if case .dictionary(let dict) = value {
            XCTAssertEqual(dict["key"], .string("value"))
        } else {
            XCTFail("Expected dictionary value")
        }
    }

    // MARK: - Nested Structures

    func testNestedDictionary() {
        let metadata: LogMetadata = [
            "user": [
                "id": 123,
                "name": "Test User",
                "active": true
            ]
        ]

        if case .dictionary(let user) = metadata["user"] {
            XCTAssertEqual(user["id"], .int(123))
            XCTAssertEqual(user["name"], .string("Test User"))
            XCTAssertEqual(user["active"], .bool(true))
        } else {
            XCTFail("Expected nested dictionary")
        }
    }

    func testNestedArray() {
        let metadata: LogMetadata = [
            "tags": ["swift", "logging", "async"]
        ]

        if case .array(let tags) = metadata["tags"] {
            XCTAssertEqual(tags.count, 3)
            XCTAssertEqual(tags[0], .string("swift"))
        } else {
            XCTFail("Expected nested array")
        }
    }

    // MARK: - JSON Conversion

    func testJsonValueString() {
        let value: LogMetadataValue = "hello"
        XCTAssertEqual(value.jsonValue as? String, "hello")
    }

    func testJsonValueInt() {
        let value: LogMetadataValue = 42
        XCTAssertEqual(value.jsonValue as? Int, 42)
    }

    func testJsonValueBool() {
        let value: LogMetadataValue = true
        XCTAssertEqual(value.jsonValue as? Bool, true)
    }

    func testJsonValueNull() {
        let value: LogMetadataValue = nil
        XCTAssertTrue(value.jsonValue is NSNull)
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let original: LogMetadata = [
            "string": "value",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "null": nil,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LogMetadata.self, from: data)

        XCTAssertEqual(decoded["string"], .string("value"))
        XCTAssertEqual(decoded["int"], .int(42))
        XCTAssertEqual(decoded["bool"], .bool(true))
        XCTAssertEqual(decoded["null"], .null)
    }

    // MARK: - Equality

    func testEquality() {
        let value1: LogMetadataValue = "test"
        let value2: LogMetadataValue = "test"
        let value3: LogMetadataValue = "other"

        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    func testDictionaryEquality() {
        let dict1: LogMetadataValue = ["a": 1, "b": 2]
        let dict2: LogMetadataValue = ["a": 1, "b": 2]
        let dict3: LogMetadataValue = ["a": 1, "b": 3]

        XCTAssertEqual(dict1, dict2)
        XCTAssertNotEqual(dict1, dict3)
    }
}
