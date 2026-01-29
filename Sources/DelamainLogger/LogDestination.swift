import Foundation

/// Protocol for log output destinations.
///
/// Destinations receive log messages and output them to their target
/// (console, file, remote service, etc.). All destinations must be actors
/// for thread safety.
public protocol LogDestination: Actor {
    /// The minimum log level this destination will accept.
    nonisolated var minimumLevel: LogLevel { get }
    
    /// Outputs a log message to the destination.
    /// - Parameter message: The message to log.
    func log(_ message: LogMessage) async
    
    /// Determines if a message at the given level should be logged.
    /// - Parameter level: The log level to check.
    /// - Returns: `true` if the level should be logged.
    func shouldLog(level: LogLevel) async -> Bool
}

/// Default implementation for shouldLog based on minimumLevel.
public extension LogDestination {
    func shouldLog(level: LogLevel) async -> Bool {
        level >= minimumLevel
    }
}
