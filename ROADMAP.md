# DelamainLogger Roadmap

This document outlines planned features and improvements for DelamainLogger.

## ✅ v1.0.0 (Released)

### Core Features
- [x] Async/await native logging with actor isolation
- [x] Thread-safe operations via Swift actors
- [x] Log levels: trace, debug, info, warning, error, critical
- [x] Structured logging with key-value metadata
- [x] Swift 6 strict concurrency with full Sendable support

### Destinations
- [x] ConsoleDestination with colors and multiple formats
- [x] FileDestination with rotation and backups
- [x] OSLogDestination for Apple unified logging

---

## v1.1.0 (Next)

### Enhancements
- [ ] **Log filtering** — Filter by level, category, or custom predicates
- [ ] **Performance metrics** — Track logging overhead and throughput
- [ ] **Batched file writes** — Reduce I/O with configurable batch sizes

### New Destinations
- [ ] **Remote destination** — Send logs to HTTP endpoints
- [ ] **SQLite destination** — Queryable local log storage

## v1.2.0 (Future)

### Advanced Features
- [ ] **Log aggregation** — Combine logs from multiple sources
- [ ] **Sampling** — Probabilistic logging for high-volume scenarios
- [ ] **Sensitive data redaction** — Automatic PII masking
- [ ] **Crash log capture** — Integrate with signal handlers

### Integrations
- [ ] **DelamainAnalytics integration** — Unified telemetry pipeline
- [ ] **CloudKit destination** — Apple-native cloud logging
- [ ] **Datadog/Sentry adapters** — Third-party observability platforms

## v2.0.0 (Long-term)

### Breaking Changes
- [ ] **Macro-based logging** — Compile-time log level stripping

### Architecture
- [ ] **Plugin system** — Dynamic destination loading
- [ ] **Log replay** — Time-travel debugging from stored logs

---

## Contributing

Want to help? Check our [issues](https://github.com/delamain-labs/DelamainLogger/issues) or open a discussion for new feature ideas.

## Related Packages

- [DelamainNetworking](https://github.com/delamain-labs/DelamainNetworking) — Async networking with retries
- [DelamainCore](https://github.com/delamain-labs/DelamainCore) — Shared utilities and extensions
- [DelamainStorage](https://github.com/delamain-labs/DelamainStorage) — Local data persistence (Coming Soon)

---

*Last updated: 2026-01-29*
