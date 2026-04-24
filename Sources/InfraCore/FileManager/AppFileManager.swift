//
//  AppFileManager.swift
//  SwiftInfrastructure

import Foundation

public final class AppFileManager: IAppFileManager {

	// MARK: - Properties

	private let fileManager: FileManager
	private let logger: LogManager

	// MARK: - Инициализация

	public init(fileManager: FileManager = .default, logger: ILogger) {
		self.fileManager = fileManager
		self.logger = LogManager(logger: logger, category: .files)
	}

	// MARK: - IAppFileManager Implementation

	public func fileExists(atPath path: String) -> Bool {
		return fileManager.fileExists(atPath: path)
	}

	public func createDirectory(atPath path: String, withIntermediateDirectories: Bool = true) throws {
		try fileManager.createDirectory(atPath: path, withIntermediateDirectories: withIntermediateDirectories)
	}

	public func moveItem(at srcURL: URL, to dstURL: URL) throws {
		// Удаляем существующий файл, если он есть
		if fileManager.fileExists(atPath: dstURL.path) {
			try fileManager.removeItem(at: dstURL)
		}

		// Перемещаем файл
		try fileManager.moveItem(at: srcURL, to: dstURL)
	}

	public func removeItem(atPath path: String) throws {
		try fileManager.removeItem(atPath: path)
	}

	public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
		return try fileManager.attributesOfItem(atPath: path)
	}

	public func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
		return fileManager.urls(for: directory, in: domainMask)
	}

	// MARK: - Debug Operations

	public func clearAllCaches() -> Bool {
		var success = true

		// 1. Очистка Caches Directory
		let cacheDirectories = urls(for: .cachesDirectory, in: .userDomainMask)
		for cacheDir in cacheDirectories {
			do {
				let cacheContents = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
				for item in cacheContents {
					try fileManager.removeItem(at: item)
				}
			} catch {
				success = false
				logger.error("❌ Failed to clear caches directory: \(error)")
			}
		}

		// 2. Очистка Temporary Directory
		let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
		do {
			let tempContents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
			for item in tempContents {
				try fileManager.removeItem(at: item)
			}
		} catch {
			success = false
			logger.error("❌ Failed to clear temporary directory: \(error)")
		}

		// 3. Очистка URLCache
		URLCache.shared.removeAllCachedResponses()

		// 4. Очистка Application Support кэшей (если есть)
		let appSupportDirectories = urls(for: .applicationSupportDirectory, in: .userDomainMask)
		for appSupportDir in appSupportDirectories {
			let cacheSubDir = appSupportDir.appendingPathComponent("Caches")
			if fileManager.fileExists(atPath: cacheSubDir.path) {
				do {
					let cacheContents = try fileManager.contentsOfDirectory(at: cacheSubDir, includingPropertiesForKeys: nil)
					for item in cacheContents {
						try fileManager.removeItem(at: item)
					}
				} catch {
					success = false
					logger.error("❌ Failed to clear application support caches: \(error)")
				}
			}
		}

		return success
	}
}
