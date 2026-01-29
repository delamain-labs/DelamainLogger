import Foundation
import SQLite

/// Error types for SQLite destination operations.
public enum SQLiteDestinationError: Error, Sendable {
    case failedToOpenDatabase(String)
    case failedToCreateTable(Error)
    case queryError(Error)
    case encodingError(Error)
}

/// A stored log entry retrieved from the database.
public struct StoredLogEntry: Sendable {
    public let id: Int64
    public let timestamp: Date
    public let level: LogLevel
    public let source: String
    public let message: String
    public let metadata: [String: String]?
    public let file: String
    public let function: String
    public let line: Int
}

/// A log destination that persists messages to a SQLite database.
public actor SQLiteDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel
    public nonisolated let databasePath: String
    public nonisolated let tableName: String
    
    private let db: Connection
    private let table: Table
    
    // Column definitions
    private let colId = Expression<Int64>("id")
    private let colTimestamp = Expression<Double>("timestamp")
    private let colLevel = Expression<Int>("level")
    private let colSource = Expression<String>("source")
    private let colMessage = Expression<String>("message")
    private let colMetadata = Expression<String?>("metadata")
    private let colFile = Expression<String>("file")
    private let colFunction = Expression<String>("function")
    private let colLine = Expression<Int>("line")
    
    public init(
        databasePath: String,
        tableName: String = "logs",
        minimumLevel: LogLevel = .trace
    ) throws {
        self.databasePath = databasePath
        self.tableName = tableName
        self.minimumLevel = minimumLevel
        
        let connection: Connection
        do {
            connection = try Connection(databasePath)
        } catch {
            throw SQLiteDestinationError.failedToOpenDatabase(databasePath)
        }
        
        self.db = connection
        
        let logTable = Table(tableName)
        self.table = logTable
        
        do {
            try connection.run(logTable.create(ifNotExists: true) { t in
                t.column(colId, primaryKey: .autoincrement)
                t.column(colTimestamp)
                t.column(colLevel)
                t.column(colSource)
                t.column(colMessage)
                t.column(colMetadata)
                t.column(colFile)
                t.column(colFunction)
                t.column(colLine)
            })
            
            try connection.run(logTable.createIndex(colTimestamp, ifNotExists: true))
            try connection.run(logTable.createIndex(colLevel, ifNotExists: true))
            try connection.run(logTable.createIndex(colSource, ifNotExists: true))
        } catch {
            throw SQLiteDestinationError.failedToCreateTable(error)
        }
    }
    
    public func log(_ message: LogMessage) async {
        guard message.level >= minimumLevel else { return }
        
        let metadataJSON: String?
        if let metadata = message.metadata, !metadata.isEmpty {
            metadataJSON = encodeMetadata(metadata)
        } else {
            metadataJSON = nil
        }
        
        do {
            try db.run(table.insert(
                colTimestamp <- message.timestamp.timeIntervalSince1970,
                colLevel <- message.level.rawValue,
                colSource <- message.source,
                colMessage <- message.message,
                colMetadata <- metadataJSON,
                colFile <- message.file,
                colFunction <- message.function,
                colLine <- message.line
            ))
        } catch {
            // Silently fail
        }
    }
    
    public func fetchAll(limit: Int? = nil, offset: Int = 0) throws -> [StoredLogEntry] {
        var query = table.order(colTimestamp.desc)
        
        if let limit = limit {
            query = query.limit(limit, offset: offset)
        } else if offset > 0 {
            query = query.limit(-1, offset: offset)
        }
        
        return try executeQuery(query)
    }
    
    public func fetch(level: LogLevel) throws -> [StoredLogEntry] {
        let query = table.filter(colLevel == level.rawValue).order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func fetch(minimumLevel: LogLevel) throws -> [StoredLogEntry] {
        let query = table.filter(colLevel >= minimumLevel.rawValue).order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func fetch(from: Date, to: Date) throws -> [StoredLogEntry] {
        let query = table
            .filter(colTimestamp >= from.timeIntervalSince1970)
            .filter(colTimestamp <= to.timeIntervalSince1970)
            .order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func fetch(source: String) throws -> [StoredLogEntry] {
        let query = table.filter(colSource == source).order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func fetch(metadataKey: String) throws -> [StoredLogEntry] {
        let pattern = "%\"\(metadataKey)\":%"
        let query = table.filter(colMetadata.like(pattern)).order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func fetch(metadataKey: String, value: String) throws -> [StoredLogEntry] {
        let pattern = "%\"\(metadataKey)\":\"\(value)\"%"
        let query = table.filter(colMetadata.like(pattern)).order(colTimestamp.desc)
        return try executeQuery(query)
    }
    
    public func count() throws -> Int {
        try db.scalar(table.count)
    }
    
    public func deleteAll() throws {
        try db.run(table.delete())
    }
    
    @discardableResult
    public func delete(olderThan date: Date) throws -> Int {
        let oldEntries = table.filter(colTimestamp < date.timeIntervalSince1970)
        return try db.run(oldEntries.delete())
    }
    
    public func close() async {
        // SQLite.swift Connection closes on deinit
    }
    
    private func executeQuery(_ query: Table) throws -> [StoredLogEntry] {
        var entries: [StoredLogEntry] = []
        
        do {
            for row in try db.prepare(query) {
                let entry = StoredLogEntry(
                    id: row[colId],
                    timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
                    level: LogLevel(rawValue: row[colLevel]) ?? .info,
                    source: row[colSource],
                    message: row[colMessage],
                    metadata: decodeMetadata(row[colMetadata]),
                    file: row[colFile],
                    function: row[colFunction],
                    line: row[colLine]
                )
                entries.append(entry)
            }
        } catch {
            throw SQLiteDestinationError.queryError(error)
        }
        
        return entries
    }
    
    private func encodeMetadata(_ metadata: LogMetadata) -> String? {
        // Convert LogMetadata to simple string dictionary for storage
        let stringDict = metadata.mapValues { $0.description }
        guard let data = try? JSONSerialization.data(withJSONObject: stringDict),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    private func decodeMetadata(_ json: String?) -> [String: String]? {
        guard let json = json,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return dict
    }
}
