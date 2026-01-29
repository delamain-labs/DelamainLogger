import Foundation

/// Error types for remote destination operations.
public enum RemoteDestinationError: Error, Sendable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case networkError(String)
    case encodingError(String)
}

/// Configuration for retry behavior.
public struct RetryConfiguration: Sendable {
    /// Maximum number of retry attempts.
    public let maxRetries: Int

    /// Base delay between retries (exponential backoff applied).
    public let baseDelay: TimeInterval

    /// Maximum delay between retries.
    public let maxDelay: TimeInterval

    /// Creates retry configuration.
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// No retries.
    public static let none = RetryConfiguration(maxRetries: 0)

    /// Default retry configuration.
    public static let `default` = RetryConfiguration()
}

/// A log destination that sends logs to a remote HTTP endpoint.
///
/// Supports batching, retries, and custom headers for authentication.
public actor RemoteDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let url: URL
    public nonisolated let batchSize: Int
    public nonisolated let flushInterval: TimeInterval
    public nonisolated let maxBufferSize: Int

    private let headers: [String: String]
    private let retryConfig: RetryConfiguration
    private let session: URLSession

    private var buffer: [LogMessage] = []
    private var droppedCount: Int = 0
    private var flushTask: Task<Void, Never>?
    private var isFlushTaskStarted: Bool = false
    private var lastFlush: Date = Date()
    private var isClosed: Bool = false

    private let encoder: JSONEncoder

    /// Creates a remote destination.
    /// - Parameters:
    ///   - url: The HTTP endpoint URL.
    ///   - minimumLevel: Minimum level to log (default: .info).
    ///   - batchSize: Number of messages to batch before sending (default: 50).
    ///   - flushInterval: Maximum seconds between flushes (default: 10).
    ///   - maxBufferSize: Maximum buffer size before dropping old messages (default: 1000).
    ///   - headers: Custom HTTP headers (e.g., for authentication).
    ///   - retryConfig: Retry configuration for failed requests.
    ///   - session: URLSession to use (default: shared).
    public init(
        url: URL,
        minimumLevel: LogLevel = .info,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 10.0,
        maxBufferSize: Int = 1000,
        headers: [String: String] = [:],
        retryConfig: RetryConfiguration = .default,
        session: URLSession = .shared
    ) {
        self.url = url
        self.minimumLevel = minimumLevel
        self.batchSize = max(1, batchSize)
        self.flushInterval = max(1.0, flushInterval)
        self.maxBufferSize = max(batchSize, maxBufferSize)
        self.headers = headers
        self.retryConfig = retryConfig
        self.session = session

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Convenience initializer with URL string.
    public init(
        urlString: String,
        minimumLevel: LogLevel = .info,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 10.0,
        maxBufferSize: Int = 1000,
        headers: [String: String] = [:],
        retryConfig: RetryConfiguration = .default,
        session: URLSession = .shared
    ) throws {
        guard let url = URL(string: urlString) else {
            throw RemoteDestinationError.invalidURL
        }
        self.init(
            url: url,
            minimumLevel: minimumLevel,
            batchSize: batchSize,
            flushInterval: flushInterval,
            maxBufferSize: maxBufferSize,
            headers: headers,
            retryConfig: retryConfig,
            session: session
        )
    }

    public func log(_ message: LogMessage) async {
        guard !isClosed else { return }
        guard message.level >= minimumLevel else { return }

        // Start periodic flush task on first log
        if !isFlushTaskStarted {
            isFlushTaskStarted = true
            flushTask = Task { [weak self] in
                await self?.runPeriodicFlush()
            }
        }

        buffer.append(message)

        if buffer.count >= batchSize {
            await flush()
        }
    }

    /// Flushes buffered messages to the remote endpoint.
    public func flush() async {
        guard !buffer.isEmpty else { return }

        let messages = buffer
        buffer.removeAll(keepingCapacity: true)
        lastFlush = Date()

        do {
            try await send(messages)
        } catch {
            // On failure, re-add messages to buffer with cap to prevent unbounded growth
            buffer.insert(contentsOf: messages, at: 0)

            // Drop oldest messages if buffer exceeds max size
            if buffer.count > maxBufferSize {
                let toDrop = buffer.count - maxBufferSize
                buffer.removeFirst(toDrop)
                droppedCount += toDrop
            }
        }
    }

    /// Returns the current number of buffered messages.
    public func bufferedCount() -> Int {
        buffer.count
    }

    /// Returns the number of messages dropped due to buffer overflow.
    public func droppedMessageCount() -> Int {
        droppedCount
    }

    /// Closes the destination, flushing remaining messages.
    public func close() async {
        isClosed = true
        flushTask?.cancel()
        await flush()
    }

    // MARK: - Private

    private func runPeriodicFlush() async {
        while !Task.isCancelled && !isClosed {
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled && !isClosed else { break }

            let timeSinceFlush = Date().timeIntervalSince(lastFlush)
            let hasBuffer = !buffer.isEmpty

            if hasBuffer && timeSinceFlush >= flushInterval {
                await flush()
            }
        }
    }

    private func send(_ messages: [LogMessage]) async throws {
        let payload = messages.map { LogPayload(from: $0) }

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw RemoteDestinationError.encodingError(error.localizedDescription)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var lastError: Error?
        var attempt = 0

        while attempt <= retryConfig.maxRetries {
            do {
                let (_, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if (200..<300).contains(statusCode) {
                        return // Success
                    } else if statusCode >= 500 {
                        // Server error, retry
                        lastError = RemoteDestinationError.requestFailed(statusCode: statusCode)
                    } else {
                        // Client error, don't retry
                        throw RemoteDestinationError.requestFailed(statusCode: statusCode)
                    }
                }
            } catch {
                if error is RemoteDestinationError {
                    throw error
                }
                lastError = RemoteDestinationError.networkError(error.localizedDescription)
            }

            attempt += 1

            if attempt <= retryConfig.maxRetries {
                let delay = min(
                    retryConfig.baseDelay * pow(2.0, Double(attempt - 1)),
                    retryConfig.maxDelay
                )
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        if let error = lastError {
            throw error
        }
    }
}

// MARK: - Payload

/// JSON-encodable log payload for remote transmission.
private struct LogPayload: Encodable {
    let timestamp: Date
    let level: String
    let source: String
    let message: String
    let metadata: [String: String]?
    let file: String
    let function: String
    let line: Int

    init(from logMessage: LogMessage) {
        self.timestamp = logMessage.timestamp
        self.level = logMessage.level.description
        self.source = logMessage.source
        self.message = logMessage.message
        self.file = URL(fileURLWithPath: logMessage.file).lastPathComponent
        self.function = logMessage.function
        self.line = logMessage.line

        // Convert LogMetadata to simple strings for JSON
        if let meta = logMessage.metadata {
            self.metadata = meta.mapValues { $0.description }
        } else {
            self.metadata = nil
        }
    }
}
