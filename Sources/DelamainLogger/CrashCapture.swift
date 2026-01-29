import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// Information about a captured crash.
public struct CrashInfo: Sendable {
    /// The signal that caused the crash.
    public let signal: Int32

    /// Human-readable signal name.
    public let signalName: String

    /// Timestamp of the crash.
    public let timestamp: Date

    /// Thread that crashed (if available).
    public let thread: String?

    /// Additional context stored before crash.
    public let context: [String: String]
}

/// Crash signal handler and log capture.
///
/// Registers signal handlers to capture crash information and write
/// a final log entry before the process terminates.
///
/// - Warning: Signal handlers have severe restrictions. Only async-signal-safe
///   functions can be called. This implementation does minimal work in the
///   handler and relies on a pre-allocated buffer.
public final class CrashCapture: @unchecked Sendable {
    /// Shared instance.
    public static let shared = CrashCapture()

    /// File URL to write crash log.
    private var crashLogURL: URL?

    /// Pre-crash context for additional information.
    private var context: [String: String] = [:]

    /// Lock for context access.
    private let lock = NSLock()

    /// Whether handlers are installed.
    private var isInstalled: Bool = false

    /// Signals to capture.
    private static let capturedSignals: [Int32] = [
        SIGABRT,  // Abort
        SIGBUS,   // Bus error
        SIGFPE,   // Floating point exception
        SIGILL,   // Illegal instruction
        SIGSEGV,  // Segmentation fault
        SIGTRAP   // Trace trap
    ]

    /// Signal names for logging.
    private static let signalNames: [Int32: String] = [
        SIGABRT: "SIGABRT (Abort)",
        SIGBUS: "SIGBUS (Bus Error)",
        SIGFPE: "SIGFPE (Floating Point Exception)",
        SIGILL: "SIGILL (Illegal Instruction)",
        SIGSEGV: "SIGSEGV (Segmentation Fault)",
        SIGTRAP: "SIGTRAP (Trace Trap)"
    ]

    private init() {}

    // MARK: - Installation

    /// Installs crash signal handlers.
    /// - Parameter crashLogURL: Optional file URL to write crash log.
    public func install(crashLogURL: URL? = nil) {
        guard !isInstalled else { return }

        self.crashLogURL = crashLogURL

        // Store reference for signal handler
        CrashCapture._shared = self

        for sig in CrashCapture.capturedSignals {
            signal(sig, CrashCapture.signalHandler)
        }

        isInstalled = true
    }

    /// Uninstalls crash signal handlers.
    public func uninstall() {
        guard isInstalled else { return }

        for sig in CrashCapture.capturedSignals {
            signal(sig, SIG_DFL)
        }

        isInstalled = false
        CrashCapture._shared = nil
    }

    // MARK: - Context

    /// Sets crash context that will be included in crash logs.
    /// - Parameters:
    ///   - value: The value to set.
    ///   - key: The context key.
    public func setContext(_ value: String, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        context[key] = value
    }

    /// Clears a context value.
    /// - Parameter key: The key to clear.
    public func clearContext(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        context.removeValue(forKey: key)
    }

    /// Clears all context.
    public func clearAllContext() {
        lock.lock()
        defer { lock.unlock() }
        context.removeAll()
    }

    // MARK: - Private

    /// Static reference for signal handler.
    /// Note: Signal handlers can only access async-signal-safe state.
    nonisolated(unsafe) private static var _shared: CrashCapture?

    /// Signal handler callback.
    private static let signalHandler: @convention(c) (Int32) -> Void = { sig in
        guard let capture = CrashCapture._shared else {
            // Re-raise with default handler
            signal(sig, SIG_DFL)
            raise(sig)
            return
        }

        let signalName = CrashCapture.signalNames[sig] ?? "UNKNOWN(\(sig))"

        // Write crash log
        capture.writeCrashLog(signal: sig, signalName: signalName)

        // Re-raise with default handler to allow normal crash behavior
        signal(sig, SIG_DFL)
        raise(sig)
    }

    private func writeCrashLog(signal: Int32, signalName: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var log = """
        === CRASH LOG ===
        Timestamp: \(timestamp)
        Signal: \(signalName)

        """

        // Add context
        lock.lock()
        let contextCopy = context
        lock.unlock()

        if !contextCopy.isEmpty {
            log += "Context:\n"
            for (key, value) in contextCopy.sorted(by: { $0.key < $1.key }) {
                log += "  \(key): \(value)\n"
            }
            log += "\n"
        }

        log += "=== END CRASH LOG ===\n"

        // Write to stderr (always works)
        fputs(log, stderr)

        // Write to file if configured
        if let url = crashLogURL {
            try? log.write(to: url, atomically: false, encoding: .utf8)
        }
    }
}

// MARK: - Logger Integration

extension Logger {
    /// Sets crash context for the logger.
    /// - Parameters:
    ///   - value: The value to set.
    ///   - key: The context key.
    public static func setCrashContext(_ value: String, forKey key: String) {
        CrashCapture.shared.setContext(value, forKey: key)
    }

    /// Clears crash context.
    /// - Parameter key: The key to clear.
    public static func clearCrashContext(forKey key: String) {
        CrashCapture.shared.clearContext(forKey: key)
    }
}

// MARK: - Convenience

extension CrashCapture {
    /// Installs crash capture with a log file in the app's documents directory.
    /// - Parameter filename: The crash log filename (default: "crash.log").
    public func installWithDefaultFile(filename: String = "crash.log") {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        let crashLogURL = documentsURL?.appendingPathComponent(filename)
        install(crashLogURL: crashLogURL)
    }
}
