//
//  MockFileDownloadService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 02.07.2025.
//

import Foundation
import InfraFileCache

/// An in-memory mock implementation of ``IFileDownloadService`` for tests and previews.
///
/// ## Overview
///
/// Simulates downloads without any real network traffic: synthesises dummy
/// file contents, reports progress on a configurable schedule, and optionally
/// injects failures.
///
/// ## Capabilities
///
/// - Produces small dummy files whose contents match the requested file extension.
/// - Emits progress callbacks on a configurable cadence.
/// - Supports tunable behaviour via ``Configuration``.
public final class MockFileDownloadService: IFileDownloadService {

	// MARK: - Configuration

	/// Tunable parameters controlling mock-download behaviour.
	public struct Configuration {
		/// How often the mock fires progress callbacks, in seconds.
		public var progressUpdateInterval: TimeInterval = 0.1

		/// How long a simulated download takes end-to-end, in seconds.
		public var totalDownloadTime: TimeInterval = 2.0

		/// Whether the mock should randomly inject failures.
		public var shouldSimulateErrors: Bool = false

		/// The probability of a simulated failure when `shouldSimulateErrors` is on, in `0.0 ... 1.0`.
		public var errorProbability: Double = 0.1

		/// The minimum size of generated dummy file contents, in bytes.
		public var minFileSize: Int = 1024

		/// The maximum size of generated dummy file contents, in bytes.
		public var maxFileSize: Int = 10240

		public init() {}

		public static let `default` = Configuration()
	}

	// MARK: - Properties

	private let configuration: Configuration
	private var activeDownloads: [String: DownloadTask] = [:]
	private let queue = DispatchQueue(label: "mock.file.download", qos: .utility)

	// MARK: - Initialization

	public init(configuration: Configuration = .default) {
		self.configuration = configuration
	}

	// MARK: - IFileDownloadService Implementation

	public func downloadFile(
		from url: URL,
		to localPath: String,
		progressHandler: ((Double) -> Void)?
	) async -> Result<URL, FileDownloadError> {

		let taskKey = makeTaskKey(url: url, localPath: localPath)

		// Проверяем, не выполняется ли уже загрузка
		if activeDownloads[taskKey] != nil {
			return .failure(.downloadInProgress)
		}

		// Симулируем ошибки, если включено
		if configuration.shouldSimulateErrors && shouldSimulateError() {
			return .failure(randomError())
		}

		// Создаем задачу загрузки
		let task = DownloadTask(
			url: url,
			localPath: localPath,
			configuration: configuration
		)

		activeDownloads[taskKey] = task

		do {
			// Симулируем процесс загрузки
			let localUrl = try await performMockDownload(
				task: task,
				progressHandler: progressHandler
			)

			// Убираем задачу из активных
			activeDownloads.removeValue(forKey: taskKey)

			return .success(localUrl)

		} catch {
			activeDownloads.removeValue(forKey: taskKey)

			if let downloadError = error as? FileDownloadError {
				return .failure(downloadError)
			} else {
				return .failure(.internalError)
			}
		}
	}

	public func pauseDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let taskKey = makeTaskKey(url: url, localPath: localPath)

		guard let task = activeDownloads[taskKey] else {
			return .failure(.taskNotFound)
		}

		task.pause()
		return .success(())
	}

	public func resumeDownload(url: URL, localPath: String) async -> Result<URL, FileDownloadError> {
		let taskKey = makeTaskKey(url: url, localPath: localPath)

		guard let task = activeDownloads[taskKey] else {
			return .failure(.taskNotFound)
		}

		if !task.isPaused {
			return .failure(.downloadInProgress)
		}

		task.resume()

		do {
			let localUrl = try await performMockDownload(
				task: task,
				progressHandler: nil
			)

			activeDownloads.removeValue(forKey: taskKey)
			return .success(localUrl)

		} catch {
			activeDownloads.removeValue(forKey: taskKey)

			if let downloadError = error as? FileDownloadError {
				return .failure(downloadError)
			} else {
				return .failure(.internalError)
			}
		}
	}

	public func cancelDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let taskKey = makeTaskKey(url: url, localPath: localPath)

		guard let task = activeDownloads[taskKey] else {
			return .failure(.taskNotFound)
		}

		task.cancel()
		activeDownloads.removeValue(forKey: taskKey)

		// Удаляем частично загруженный файл
		try? FileManager.default.removeItem(atPath: localPath)

		return .success(())
	}

	public func getDownloadProgress(url: URL, localPath: String) async -> Double? {
		let taskKey = makeTaskKey(url: url, localPath: localPath)
		return activeDownloads[taskKey]?.progress
	}

	// MARK: - Private Methods

	private func performMockDownload(
		task: DownloadTask,
		progressHandler: ((Double) -> Void)?
	) async throws -> URL {

		let totalSteps = Int(configuration.totalDownloadTime / configuration.progressUpdateInterval)

		// Создаем директорию, если она не существует
		let directory = URL(fileURLWithPath: task.localPath).deletingLastPathComponent().path
		try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

		// Симулируем прогресс загрузки
		for step in 0...totalSteps {
			// Проверяем состояние задачи
			if task.isCancelled {
				throw FileDownloadError.noResumeData
			}

			// Ждем, пока задача на паузе
			while task.isPaused && !task.isCancelled {
				try await Task.sleep(nanoseconds: UInt64(100_000_000)) // 100ms
			}

			if task.isCancelled {
				throw FileDownloadError.noResumeData
			}

			// Обновляем прогресс
			let progress = min(Double(step) / Double(totalSteps), 1.0)
			task.updateProgress(progress)

			// Уведомляем о прогрессе
			progressHandler?(progress)

			// Задержка между обновлениями
			if step < totalSteps {
				try await Task.sleep(nanoseconds: UInt64(configuration.progressUpdateInterval * 1_000_000_000))
			}
		}

		// Создаем финальный файл
		let fileData = generateMockFileData(for: task.url)
		let localUrl = URL(fileURLWithPath: task.localPath)

		try fileData.write(to: localUrl)

		return localUrl
	}

	private func generateMockFileData(for url: URL) -> Data {
		let fileExtension = url.pathExtension.lowercased()
		let fileSize = Int.random(in: configuration.minFileSize...configuration.maxFileSize)

		switch fileExtension {
		case "jpg", "jpeg":
			return generateMockImageData(size: fileSize, type: "JPEG")
		case "png":
			return generateMockImageData(size: fileSize, type: "PNG")
		case "pdf":
			return generateMockPDFData(size: fileSize)
		case "txt":
			return generateMockTextData(size: fileSize)
		default:
			return generateMockGenericData(size: fileSize)
		}
	}

	private func generateMockImageData(size: Int, type: String) -> Data {
		var data = Data()

		// Добавляем простой заголовок
		let header = "MOCK_\(type)_IMAGE_DATA\n".data(using: .utf8) ?? Data()
		data.append(header)

		// Заполняем до нужного размера
		let remainingSize = size - data.count
		if remainingSize > 0 {
			let padding = Data(repeating: UInt8.random(in: 0...255), count: remainingSize)
			data.append(padding)
		}

		return data
	}

	private func generateMockPDFData(size: Int) -> Data {
		var data = Data()

		// Простой PDF заголовок
		let header = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n".data(using: .utf8) ?? Data()
		data.append(header)

		// Заполняем до нужного размера
		let remainingSize = size - data.count
		if remainingSize > 0 {
			let content = String(repeating: "Mock PDF content. ", count: remainingSize / 18)
			if let contentData = content.data(using: .utf8) {
				data.append(contentData)
			}
		}

		return data
	}

	private func generateMockTextData(size: Int) -> Data {
		let content = String(repeating: "This is mock text content for testing purposes. ", count: size / 48)
		return content.data(using: .utf8) ?? Data()
	}

	private func generateMockGenericData(size: Int) -> Data {
		return Data(repeating: UInt8.random(in: 0...255), count: size)
	}

	private func makeTaskKey(url: URL, localPath: String) -> String {
		return "\(url.absoluteString)|\(localPath)"
	}

	private func shouldSimulateError() -> Bool {
		return Double.random(in: 0...1) < configuration.errorProbability
	}

	private func randomError() -> FileDownloadError {
		let errors: [FileDownloadError] = [
			.noInternetConnection,
			.serverError(statusCode: 500),
			.serverError(statusCode: 404),
			.timeout,
			.invalidUrl
		]

		return errors.randomElement() ?? .internalError
	}
}

// MARK: - Download Task

private final class DownloadTask {
	let url: URL
	let localPath: String
	let configuration: MockFileDownloadService.Configuration

	private(set) var progress: Double = 0.0
	private(set) var isPaused: Bool = false
	private(set) var isCancelled: Bool = false

	private let lock = NSLock()

	init(url: URL, localPath: String, configuration: MockFileDownloadService.Configuration) {
		self.url = url
		self.localPath = localPath
		self.configuration = configuration
	}

	func updateProgress(_ progress: Double) {
		lock.lock()
		defer { lock.unlock() }
		self.progress = progress
	}

	func pause() {
		lock.lock()
		defer { lock.unlock() }
		isPaused = true
	}

	func resume() {
		lock.lock()
		defer { lock.unlock() }
		isPaused = false
	}

	func cancel() {
		lock.lock()
		defer { lock.unlock() }
		isCancelled = true
	}
}

// MARK: - Convenience Extensions

extension MockFileDownloadService {

	/// Builds a mock configured for fast downloads, suitable for unit tests.
	public static func fastMock() -> MockFileDownloadService {
		var config = Configuration.default
		config.totalDownloadTime = 0.5
		config.progressUpdateInterval = 0.05
		return MockFileDownloadService(configuration: config)
	}

	/// Builds a mock configured for slow downloads, suitable for UI demos where progress visibility matters.
	public static func slowMock() -> MockFileDownloadService {
		var config = Configuration.default
		config.totalDownloadTime = 5.0
		config.progressUpdateInterval = 0.2
		return MockFileDownloadService(configuration: config)
	}

	/// Builds a mock with a high failure probability, suitable for tests that verify error-handling paths.
	public static func errorProneMock() -> MockFileDownloadService {
		var config = Configuration.default
		config.shouldSimulateErrors = true
		config.errorProbability = 0.3
		return MockFileDownloadService(configuration: config)
	}

	/// Clears every in-flight mock download. Intended for test teardown.
	public func clearActiveDownloads() {
		activeDownloads.removeAll()
	}

	/// The number of in-flight mock downloads.
	public var activeDownloadCount: Int {
		return activeDownloads.count
	}
}
