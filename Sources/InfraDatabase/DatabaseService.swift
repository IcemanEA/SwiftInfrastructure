//
//  DatabaseService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 25.06.2025.
//

import Foundation
import GRDB
import InfraCore

// MARK: - Protocols

/// A consumer-supplied registrar of GRDB migrations for a specific project.
///
/// Each consuming project implements this protocol once and passes an instance
/// to ``IDatabaseService/migrate(with:)``. `SwiftInfrastructure` ships no
/// migrations of its own — schema is the consumer's concern.
public protocol IDatabaseMigrator: Sendable {
	/// Registers the project's migrations on the GRDB migrator.
	func registerMigrations(on migrator: inout DatabaseMigrator)
}

/// A service that configures and manages the SQLite database.
///
/// Sits in the infrastructure layer and handles low-level concerns: pool
/// construction, GRDB configuration, running consumer-supplied migrations,
/// and high-privilege operations such as clearing or inspecting the store.
public protocol IDatabaseService: Sendable {
	/// The connection pool, open from the moment the service is created.
	var dbPool: DatabasePool { get }

	/// Registers the consumer's migrations and applies the pending ones to ``dbPool``.
	///
	/// In debug builds the database is erased when a migration's definition changes.
	///
	/// - Parameter migrator: The project's migration registrar.
	/// - Throws: Any error raised by a migration.
	func migrate(with migrator: IDatabaseMigrator) async throws

	/// Deletes every row of every user table and compacts the file.
	///
	/// - Throws: Any error raised by SQLite.
	func clearDatabase() async throws
}

// MARK: - Implementation

public final class DatabaseService: IDatabaseService, Sendable {

	// MARK: - Properties

	public let dbPool: DatabasePool
	private let logger: LogManager

	// MARK: - Initialization

	/// Opens the database file and its connection pool.
	///
	/// The file is created at `<Application Support>/<bundleID>/<databaseName>` when it
	/// does not exist. No migration runs here; call ``migrate(with:)`` afterwards.
	///
	/// - Parameters:
	///   - logger: The sink for the service's log messages.
	///   - databaseName: The file name of the SQLite database, for example `"app.sqlite"`.
	///   - bundleID: The name of the Application Support sub-directory, usually the app's bundle identifier.
	/// - Throws: An error when the directory cannot be created or the pool cannot be opened.
	public init(logger: ILogger, databaseName: String, bundleID: String) throws {
		let logger = LogManager(logger: logger, category: .database)
		let databaseURL = try Self.getDatabaseURL(bundleID: bundleID, databaseName: databaseName)

		self.dbPool = try DatabasePool(path: databaseURL.path, configuration: Self.makeConfiguration())
		self.logger = logger

		logger.info("Database opened at: \(databaseURL.path)")
	}

	// MARK: - Public Methods

	public func migrate(with projectMigrator: IDatabaseMigrator) async throws {
		var migrator = DatabaseMigrator()

#if DEBUG
		migrator.eraseDatabaseOnSchemaChange = true
#endif

		// Регистрируем миграции проекта
		projectMigrator.registerMigrations(on: &migrator)

		try migrator.migrate(dbPool)
		logger.info("Database migrations completed")
	}

	public func clearDatabase() async throws {
		try await dbPool.write { db in
			// Получаем все пользовательские таблицы
			let tableNames = try String.fetchAll(db, sql:
				"""
				SELECT name FROM sqlite_master
				WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
				""")

			// Удаляем данные из всех таблиц
			for tableName in tableNames {
				try db.execute(sql: "DELETE FROM \(tableName)")
			}

			// Сбрасываем автоинкремент
			try db.execute(sql: "DELETE FROM sqlite_sequence WHERE 1=1")

			// Оптимизируем БД после удаления
			try db.execute(sql: "VACUUM")
		}

		logger.info("Database cleared")
	}

	// MARK: - Performance and Analytics Extensions

	/// Returns information about the on-disk size and per-table shape of the database.
	public func getDatabaseInfo() async throws -> DatabaseInfo {
		return try await dbPool.read { db in
			let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
			let pageSize = try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 0
			let freePages = try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0

			let totalSize = pageCount * pageSize
			let freeSize = freePages * pageSize
			let usedSize = totalSize - freeSize

			// Получаем статистику по таблицам
			let tablesInfo = try Row.fetchAll(db, sql:
				"""
				SELECT
				name,
				COUNT(*) as rowCount
				FROM sqlite_master
				WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
				GROUP BY name
				""").compactMap { row -> TableInfo? in
					guard let name: String = row["name"] else { return nil }
					let rowCount: Int = row["rowCount"] ?? 0
					return TableInfo(name: name, rowCount: rowCount)
				}

			return DatabaseInfo(
				totalSizeBytes: totalSize,
				usedSizeBytes: usedSize,
				freeSizeBytes: freeSize,
				pageCount: pageCount,
				pageSize: pageSize,
				tables: tablesInfo
			)
		}
	}

	/// Optimizes the database: refreshes statistics, rebuilds indexes, and compacts free space.
	public func optimizeDatabase() async throws {
		try await dbPool.write { db in
			// Анализируем таблицы для обновления статистики
			try db.execute(sql: "ANALYZE")

			// Пересобираем индексы
			try db.execute(sql: "REINDEX")

			// Уплотняем БД
			try db.execute(sql: "VACUUM")
		}
	}

	// MARK: - Private Methods

	private static func getDatabaseURL(bundleID: String, databaseName: String) throws -> URL {
		let fileManager = FileManager.default
		let appSupport = try fileManager.url(
			for: .applicationSupportDirectory,
			in: .userDomainMask,
			appropriateFor: nil,
			create: true
		)

		let appFolder = appSupport.appendingPathComponent(bundleID)

		try fileManager.createDirectory(
			at: appFolder,
			withIntermediateDirectories: true,
			attributes: nil
		)

		return appFolder.appendingPathComponent(databaseName)
	}

	private static func makeConfiguration() -> Configuration {
		var config = Configuration()
		config.readonly = false
		config.foreignKeysEnabled = true
		config.maximumReaderCount = 10
		config.busyMode = .timeout(5.0)
		config.qos = .userInitiated

#if DEBUG
		config.publicStatementArguments = true
#endif

		config.prepareDatabase { db in
			// Оптимизации SQLite
			try db.execute(sql: "PRAGMA journal_mode = WAL")
			try db.execute(sql: "PRAGMA synchronous = NORMAL")
			try db.execute(sql: "PRAGMA cache_size = -64000") // 64MB
			try db.execute(sql: "PRAGMA temp_store = MEMORY")

			// Дополнительные настройки безопасности
			try db.execute(sql: "PRAGMA cipher_page_size = 4096")
			try db.execute(sql: "PRAGMA kdf_iter = 256000") // Увеличиваем количество итераций для большей безопасности
		}

		return config
	}
}
