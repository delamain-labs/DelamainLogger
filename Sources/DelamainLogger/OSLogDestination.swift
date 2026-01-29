import Foundation
import OSLog

/// A log destination that outputs to Apple's unified logging system (OSLog).
///
/// This integrates with Console.app and other system log viewers.
public actor OSLogDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let subsystem: String
    public nonisolated let category: String
    
    private let osLog: OSLog
    
    /// Creates an OSLog destination.
    /// - Parameters:
    ///   - subsystem: The subsystem identifier (typically reverse-DNS).
    ///   - category: The category within the subsystem.
    ///   - minimumLevel: Minimum level to log (default: .trace).
    public init(
        subsystem: String,
        category: String,
        minimumLevel: LogLevel = .trace
    ) {
        self.subsystem = subsystem
        self.category = category
        self.minimumLevel = minimumLevel
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func log(_ message: LogMessage) async {
        let type = osLogType(for: message.level)
        
        // Build the message with metadata
        var logString = message.message
        if let metadata = message.metadata, !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logString += " [\(metaStr)]"
        }
        
        os_log("%{public}@", log: osLog, type: type, logString)
    }
    
    /// Maps a DelamainLogger level to an OSLogType.
    /// - Parameter level: The log level.
    /// - Returns: The corresponding OSLogType.
    public nonisolated func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .trace, .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
}
