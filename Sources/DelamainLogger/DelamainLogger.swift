// DelamainLogger
// A lightweight, async-first logging framework for Swift 6.
//
// Copyright (c) 2026 Delamain Labs
// MIT License

/// DelamainLogger provides a modern, thread-safe logging system designed
/// for Swift 6 and structured concurrency.
///
/// ## Quick Start
/// ```swift
/// // Use the shared logger
/// await Logger.shared.info("Application started")
///
/// // Or create a custom logger
/// let logger = Logger(subsystem: "com.example.app", category: "network")
/// await logger.addDestination(ConsoleDestination())
/// await logger.addDestination(OSLogDestination(subsystem: "com.example.app", category: "network"))
///
/// await logger.debug("Request started", metadata: ["url": "/api/users"])
/// await logger.error("Request failed", metadata: ["statusCode": "500"])
/// ```
///
/// ## Features
/// - **Async/await native**: Built for structured concurrency
/// - **Thread-safe**: All operations are actor-isolated
/// - **Structured logging**: Support for key-value metadata
/// - **Multiple destinations**: Console, file, OSLog, or custom
/// - **Log levels**: trace, debug, info, warning, error, critical
/// - **File rotation**: Automatic rotation by size with backups
/// - **Apple integration**: OSLog support for Console.app
///
/// ## Destinations
/// - ``ConsoleDestination``: Output to stdout/stderr
/// - ``FileDestination``: Write to files with optional rotation
/// - ``OSLogDestination``: Integrate with Apple's unified logging
/// - Custom: Implement ``LogDestination`` protocol
