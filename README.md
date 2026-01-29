# DelamainLogger

A lightweight, async-first logging framework for Swift 6.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20watchOS%2010%20|%20tvOS%2017%20|%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Async/await native** - Built for structured concurrency
- **Thread-safe** - All operations are actor-isolated  
- **Structured logging** - Support for key-value metadata
- **Multiple destinations** - Console, file, OSLog, or custom
- **Log levels** - trace, debug, info, warning, error, critical
- **File rotation** - Automatic rotation by size with backups
- **Apple integration** - OSLog support for Console.app

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/delamain-labs/DelamainLogger.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Packages → Enter the repository URL.

## Quick Start

```swift
import DelamainLogger

// Use the shared logger
await Logger.shared.info("Application started")

// Or create a custom logger
let logger = Logger(subsystem: "com.example.app", category: "network")
await logger.addDestination(ConsoleDestination())
await logger.info("Ready")
```

## Log Levels

| Level | Use Case |
|-------|----------|
| `.trace` | Extremely detailed debugging info |
| `.debug` | Debug-level information |
| `.info` | General information |
| `.warning` | Warning conditions |
| `.error` | Error conditions |
| `.critical` | Critical/fatal errors |

## Destinations

### ConsoleDestination

Output to stdout/stderr with optional colors and formats.

```swift
// Basic
let console = ConsoleDestination()

// With options
let console = ConsoleDestination(
    minimumLevel: .info,
    format: .verbose,
    useColors: true
)

await logger.addDestination(console)
```

Formats: `.compact`, `.standard`, `.verbose`, `.json`

### FileDestination

Write to files with optional rotation.

```swift
let logFile = URL(fileURLWithPath: "/var/log/myapp.log")

let file = try FileDestination(
    fileURL: logFile,
    minimumLevel: .warning,
    createDirectories: true,
    maxFileSize: 10_000_000,  // 10 MB
    maxBackupCount: 5
)

await logger.addDestination(file)
```

### OSLogDestination

Integrate with Apple's unified logging system.

```swift
let osLog = OSLogDestination(
    subsystem: "com.example.app",
    category: "network"
)

await logger.addDestination(osLog)
```

View logs in Console.app or via `log stream`.

## Structured Logging

Include metadata for context:

```swift
await logger.info(
    "User logged in",
    metadata: [
        "userId": "12345",
        "method": "oauth"
    ]
)

await logger.error(
    "Request failed",
    metadata: [
        "statusCode": "500",
        "url": "/api/users"
    ]
)
```

## Custom Destinations

Implement the `LogDestination` protocol:

```swift
actor SlackDestination: LogDestination {
    let minimumLevel: LogLevel = .error
    let webhookURL: URL
    
    init(webhookURL: URL) {
        self.webhookURL = webhookURL
    }
    
    func log(_ message: LogMessage) async {
        // Send to Slack webhook
    }
}
```

## Thread Safety

DelamainLogger is built on Swift actors, making all operations inherently thread-safe:

```swift
// Safe to call from any context
await withTaskGroup(of: Void.self) { group in
    for i in 0..<1000 {
        group.addTask {
            await logger.info("Message \(i)")
        }
    }
}
```

## Best Practices

1. **Use appropriate levels** - Don't log everything at `.info`
2. **Include metadata** - Context makes debugging easier
3. **Use subsystems** - Organize logs by component
4. **Filter in production** - Set higher minimum levels
5. **Rotate files** - Prevent disk space issues

## Requirements

- Swift 6.0+
- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+ / visionOS 1.0+

## License

MIT License. See [LICENSE](LICENSE) for details.

## Part of Delamain Labs

This package is part of the Delamain Swift ecosystem:

- [DelamainCore](https://github.com/delamain-labs/DelamainCore) - Core utilities
- [DelamainNetworking](https://github.com/delamain-labs/DelamainNetworking) - Async networking
- **DelamainLogger** - Logging framework
