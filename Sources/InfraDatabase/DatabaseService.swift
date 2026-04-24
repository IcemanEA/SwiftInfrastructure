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
/// to ``IDatabaseService/setup(with:)``. `SwiftInfrastructure` ships no
/// migrations of its own — schema is the consumer's concern.
public protocol IDatabaseMigrator {
	/// Registers the project's migrations on the GRDB migrator.
	func registerMigrations(on migrator: inout DatabaseMigrator)
}

/// A service that configures and manages the SQLite database.
///
/// Sits in the infrastructure layer and handles low-level concerns: pool
/// construction, GRDB configuration, running consumer-supplied migrations,
/// and high-privilege operations such as clearing or inspecting the store.
public protocol IDatabaseService {
	var dbPool: DatabasePool? { get }
	func setup(with migrator: IDatabaseMigrator?) async throws
	func clearDatabase() async throws
}

// MARK: - Implementation

public final class DatabaseService: IDatabaseService {

	// MARK: - Properties

	public private(set) var dbPool: DatabasePool?
	private let logger: LogManager
	private let databaseName: String
	private let bundleID: String

	// MARK: - Initialization

	public init(logger: ILogger, databaseName: String, bundleID: String) {
		self.logger = LogManager(logger: logger, category: .database)
		self.databaseName = databaseName
		self.bundleID = bundleID
	}

	// MARK: - Public Methods

	public func setup(with projectMigrator: IDatabaseMigrator? = nil) async throws {
		let databaseURL = try getDatabaseURL()
		let config = try makeConfiguration()

		dbPool = try DatabasePool(path: databaseURL.path, configuration: config)

		if let projectMigrator = projectMigrator {
			try await performMigrations(with: projectMigrator)
		}

		logger.info("Database setup completed at: \(databaseURL.path)")
	}

	public func clearDatabase() async throws {
		guard let dbPool = dbPool else {
			throw DatabaseError.initializationFailed("Database pool is not initialized")
		}

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
		guard let dbPool = dbPool else {
			throw DatabaseError.initializationFailed("Database pool is not initialized")
		}

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
		guard let dbPool = dbPool else {
			throw DatabaseError.initializationFailed("Database pool is not initialized")
		}

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

	private func getDatabaseURL() throws -> URL {
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

	private func makeConfiguration() throws -> Configuration {
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

	private func performMigrations(with projectMigrator: IDatabaseMigrator) async throws {
		guard let dbPool = dbPool else {
			throw DatabaseError.initializationFailed("Database pool is not initialized")
		}

		var migrator = DatabaseMigrator()

#if DEBUG
		migrator.eraseDatabaseOnSchemaChange = true
#endif

		// Регистрируем миграции проекта
		projectMigrator.registerMigrations(on: &migrator)

		try migrator.migrate(dbPool)
		logger.info("Database migrations completed")
	}
}
