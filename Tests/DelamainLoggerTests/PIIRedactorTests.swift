import Testing
import Foundation
@testable import DelamainLogger

@Suite("PIIRedactor Tests")
struct PIIRedactorTests {

    // MARK: - Email Redaction

    @Test("Redacts email addresses")
    func redactsEmail() {
        let redactor = PIIRedactor(patterns: [.email])

        let input = "Contact user@example.com for support"
        let result = redactor.redact(input)

        #expect(result == "Contact [EMAIL] for support")
        #expect(!result.contains("@"))
    }

    @Test("Redacts multiple emails")
    func redactsMultipleEmails() {
        let redactor = PIIRedactor(patterns: [.email])

        let input = "From: a@b.com To: x@y.org"
        let result = redactor.redact(input)

        #expect(result == "From: [EMAIL] To: [EMAIL]")
    }

    // MARK: - Phone Redaction

    @Test("Redacts phone numbers")
    func redactsPhone() {
        let redactor = PIIRedactor(patterns: [.phone])

        let formats = [
            "Call 555-123-4567",
            "Call (555) 123-4567",
            "Call 555.123.4567",
            "Call +1 555 123 4567"
        ]

        for input in formats {
            let result = redactor.redact(input)
            #expect(result.contains("[PHONE]"), "Failed for: \(input)")
        }
    }

    // MARK: - SSN Redaction

    @Test("Redacts SSN")
    func redactsSSN() {
        let redactor = PIIRedactor(patterns: [.ssn])

        let formats = [
            "SSN: 123-45-6789",
            "SSN: 123 45 6789",
            "SSN: 123456789"
        ]

        for input in formats {
            let result = redactor.redact(input)
            #expect(result.contains("[SSN]"), "Failed for: \(input)")
        }
    }

    // MARK: - Credit Card Redaction

    @Test("Redacts credit card numbers")
    func redactsCreditCard() {
        let redactor = PIIRedactor(patterns: [.creditCard])

        let formats = [
            "Card: 4111-1111-1111-1111",
            "Card: 4111 1111 1111 1111",
            "Card: 4111111111111111"
        ]

        for input in formats {
            let result = redactor.redact(input)
            #expect(result.contains("[CARD]"), "Failed for: \(input)")
        }
    }

    // MARK: - IP Address Redaction

    @Test("Redacts IP addresses")
    func redactsIP() {
        let redactor = PIIRedactor(patterns: [.ipAddress])

        let input = "Client IP: 192.168.1.100"
        let result = redactor.redact(input)

        #expect(result == "Client IP: [IP]")
    }

    // MARK: - Token Redaction

    @Test("Redacts bearer tokens")
    func redactsBearerToken() {
        let redactor = PIIRedactor(patterns: [.bearerToken])

        let input = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc"
        let result = redactor.redact(input)

        #expect(result.contains("[TOKEN]"))
        #expect(!result.contains("eyJ"))
    }

    @Test("Redacts JWT tokens")
    func redactsJWT() {
        let redactor = PIIRedactor(patterns: [.jwt])

        let input = "Token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature"
        let result = redactor.redact(input)

        #expect(result.contains("[JWT]"))
    }

    // MARK: - Password Redaction

    @Test("Redacts passwords")
    func redactsPassword() {
        let redactor = PIIRedactor(patterns: [.password])

        let formats = [
            "password=secret123",
            "password: secret123",
            "pwd=mypassword"
        ]

        for input in formats {
            let result = redactor.redact(input)
            #expect(result.contains("[REDACTED]"), "Failed for: \(input)")
            #expect(!result.contains("secret"), "Leaked secret for: \(input)")
        }
    }

    // MARK: - Multiple Patterns

    @Test("Applies multiple patterns")
    func appliesMultiplePatterns() {
        let redactor = PIIRedactor(patterns: PIIPattern.common)

        let input = "User user@test.com called from 555-123-4567"
        let result = redactor.redact(input)

        #expect(result.contains("[EMAIL]"))
        #expect(result.contains("[PHONE]"))
        #expect(!result.contains("@"))
        #expect(!result.contains("555"))
    }

    // MARK: - Metadata Redaction

    @Test("Redacts metadata values")
    func redactsMetadata() {
        let redactor = PIIRedactor(patterns: [.email])

        let metadata: LogMetadata = [
            "email": "user@example.com",
            "safe": "no pii here"
        ]

        let result = redactor.redact(metadata)

        #expect(result?["email"] == .string("[EMAIL]"))
        #expect(result?["safe"] == .string("no pii here"))
    }

    @Test("Redacts nested metadata")
    func redactsNestedMetadata() {
        let redactor = PIIRedactor(patterns: [.email])

        let metadata: LogMetadata = [
            "user": ["email": "test@test.com", "name": "John"]
        ]

        let result = redactor.redact(metadata)

        if case .dictionary(let user) = result?["user"] {
            #expect(user["email"] == .string("[EMAIL]"))
            #expect(user["name"] == .string("John"))
        } else {
            Issue.record("Expected dictionary")
        }
    }

    // MARK: - LogMessage Redaction

    @Test("Redacts log message")
    func redactsLogMessage() {
        let redactor = PIIRedactor(patterns: [.email, .phone])

        let message = LogMessage(
            level: .info,
            message: "User user@test.com called 555-123-4567",
            metadata: ["contact": "other@email.com"],
            source: "Test"
        )

        let result = redactor.redact(message)

        #expect(result.message.contains("[EMAIL]"))
        #expect(result.message.contains("[PHONE]"))
        #expect(result.metadata?["contact"] == .string("[EMAIL]"))
        #expect(result.level == message.level)
        #expect(result.source == message.source)
    }

    // MARK: - No Match

    @Test("Preserves text without PII")
    func preservesCleanText() {
        let redactor = PIIRedactor(patterns: PIIPattern.all)

        let input = "This is a normal log message with no sensitive data"
        let result = redactor.redact(input)

        #expect(result == input)
    }

    // MARK: - Custom Patterns

    @Test("Supports custom patterns")
    func supportsCustomPatterns() {
        let customPattern = PIIPattern(
            name: "orderId",
            pattern: #"ORD-\d{8}"#,
            replacement: "[ORDER]"
        )
        let redactor = PIIRedactor(patterns: [customPattern])

        let input = "Processing order ORD-12345678"
        let result = redactor.redact(input)

        #expect(result == "Processing order [ORDER]")
    }

    // MARK: - Pattern Groups

    @Test("Common patterns group works")
    func commonPatternsWork() {
        let redactor = PIIRedactor(patterns: PIIPattern.common)

        #expect(redactor.patterns.count == 4)
    }

    @Test("Security patterns group works")
    func securityPatternsWork() {
        let redactor = PIIRedactor(patterns: PIIPattern.security)

        #expect(redactor.patterns.count == 4)
    }

    @Test("All patterns group works")
    func allPatternsWork() {
        let redactor = PIIRedactor(patterns: PIIPattern.all)

        #expect(redactor.patterns.count == 9)
    }
}
