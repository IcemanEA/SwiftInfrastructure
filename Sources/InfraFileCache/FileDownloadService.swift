//
//  FileDownloadService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.07.2025.
//

import Foundation
import InfraCore

/// The concrete ``IFileDownloadService`` implementation.
///
/// ## Overview
///
/// Downloads files from remote URLs into local storage with progress
/// reporting, pause, resume, and cancel support. All methods are asynchronous
/// and thread-safe.
public final class FileDownloadService: NSObject, IFileDownloadService {

	// MARK: - Зависимости

	private let logger: LogManager
	private let appFileManager: IAppFileManager
	private lazy var urlSession: URLSession = {
		// Настраиваем URL сессию для загрузок
		let configuration = URLSessionConfiguration.default
		configuration.timeoutIntervalForRequest = 30.0
		configuration.timeoutIntervalForResource = 300.0 // 5 минут
		configuration.allowsCellularAccess = true
		configuration.waitsForConnectivity = true
		configuration.httpMaximumConnectionsPerHost = 4

		let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
		return session
	}()

	// MARK: - Управление состоянием

	private var activeDownloads: [String: DownloadTask] = [:]
	private let downloadQueue = DispatchQueue(label: "infra.filecache.download", qos: .utility)

	// MARK: - Вспомогательные типы

	private class DownloadTask {
		let url: URL
		let localPath: String
		let progressHandler: ((Double) -> Void)?
		var downloadTask: URLSessionDownloadTask?
		var resumeData: Data?
		var completion: ((Result<URL, FileDownloadError>) -> Void)?

		init(url: URL, localPath: String, progressHandler: ((Double) -> Void)?) {
			self.url = url
			self.localPath = localPath
			self.progressHandler = progressHandler
		}
	}

	// MARK: - Инициализация

	public init(logger: ILogger, appFileManager: IAppFileManager) {
		self.logger = LogManager(logger: logger, category: .files)
		self.appFileManager = appFileManager
		super.init()
	}

	deinit {
		downloadQueue.sync {
			// Отменяем все активные загрузки
			for (_, task) in activeDownloads {
				task.downloadTask?.cancel()
			}
			activeDownloads.removeAll()
		}
		urlSession.invalidateAndCancel()
	}

	// MARK: - IFileDownloadService Implementation

	public func downloadFile(
		from url: URL,
		to localPath: String,
		progressHandler: ((Double) -> Void)?
	) async -> Result<URL, FileDownloadError> {
		logger.info("📥 Начало загрузки: \(url.absoluteString) → \(localPath)")

		let taskKey = generateTaskKey(url: url, localPath: localPath)

		return await withCheckedContinuation { continuation in
			downloadQueue.async { [weak self] in
				guard let self = self else {
					continuation.resume(returning: .failure(.internalError))
					return
				}

				// Проверяем, не выполняется ли уже загрузка
				if self.activeDownloads[taskKey] != nil {
					continuation.resume(returning: .failure(.downloadInProgress))
					return
				}

				// Создаем задачу загрузки
				let downloadTask = DownloadTask(url: url, localPath: localPath, progressHandler: progressHandler)
				downloadTask.completion = { result in
					continuation.resume(returning: result)
				}

				self.activeDownloads[taskKey] = downloadTask

				// Запускаем загрузку
				let urlSessionTask = self.urlSession.downloadTask(with: url)
				downloadTask.downloadTask = urlSessionTask
				urlSessionTask.resume()

				self.logger.info("📥 Задача загрузки запущена для: \(url.absoluteString)")
			}
		}
	}

	public func pauseDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let taskKey = generateTaskKey(url: url, localPath: localPath)

		return await withCheckedContinuation { continuation in
			downloadQueue.async { [weak self] in
				guard let self = self,
					  let downloadTask = self.activeDownloads[taskKey],
					  let urlSessionTask = downloadTask.downloadTask else {
					continuation.resume(returning: .failure(.taskNotFound))
					return
				}

				urlSessionTask.cancel { resumeData in
					downloadTask.resumeData = resumeData
					self.logger.info("📥 Загрузка приостановлена: \(url.absoluteString)")
					continuation.resume(returning: .success(()))
				}
			}
		}
	}

	public func resumeDownload(url: URL, localPath: String) async -> Result<URL, FileDownloadError> {
		let taskKey = generateTaskKey(url: url, localPath: localPath)

		return await withCheckedContinuation { continuation in
			downloadQueue.async { [weak self] in
				guard let self = self,
					  let downloadTask = self.activeDownloads[taskKey],
					  let resumeData = downloadTask.resumeData else {
					continuation.resume(returning: .failure(.noResumeData))
					return
				}

				downloadTask.completion = { result in
					continuation.resume(returning: result)
				}

				let urlSessionTask = self.urlSession.downloadTask(withResumeData: resumeData)
				downloadTask.downloadTask = urlSessionTask
				downloadTask.resumeData = nil
				urlSessionTask.resume()

				self.logger.info("📥 Загрузка возобновлена: \(url.absoluteString)")
			}
		}
	}

	public func cancelDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let taskKey = generateTaskKey(url: url, localPath: localPath)

		return await withCheckedContinuation { continuation in
			downloadQueue.async { [weak self] in
				guard let self = self,
					  let downloadTask = self.activeDownloads[taskKey] else {
					continuation.resume(returning: .failure(.taskNotFound))
					return
				}

				downloadTask.downloadTask?.cancel()
				self.activeDownloads.removeValue(forKey: taskKey)

				self.logger.info("📥 Загрузка отменена: \(url.absoluteString)")
				continuation.resume(returning: .success(()))
			}
		}
	}

	public func getDownloadProgress(url: URL, localPath: String) async -> Double? {
		let taskKey = generateTaskKey(url: url, localPath: localPath)

		return await withCheckedContinuation { continuation in
			downloadQueue.async { [weak self] in
				guard let self = self,
					  let downloadTask = self.activeDownloads[taskKey],
					  let urlSessionTask = downloadTask.downloadTask else {
					continuation.resume(returning: nil)
					return
				}

				let progress = urlSessionTask.progress.fractionCompleted
				continuation.resume(returning: progress)
			}
		}
	}

	// MARK: - Приватные методы

	/// Builds the stable key used to deduplicate concurrent downloads of the same `(url, localPath)` pair.
	private func generateTaskKey(url: URL, localPath: String) -> String {
		return "\(url.absoluteString)|\(localPath)"
	}

	/// Maps a system `Error` into the library's ``FileDownloadError`` domain.
	private func mapToFileDownloadError(_ error: Error) -> FileDownloadError {
		if let urlError = error as? URLError {
			switch urlError.code {
			case .notConnectedToInternet, .networkConnectionLost:
				return .noInternetConnection
			case .timedOut:
				return .timeout
			case .unsupportedURL, .badURL:
				return .invalidUrl
			case .httpTooManyRedirects, .badServerResponse:
				return .serverError(statusCode: urlError.errorCode)
			default:
				return .internalError
			}
		} else if (error as NSError).domain == NSPOSIXErrorDomain && (error as NSError).code == 28 { // ENOSPC
			return .insufficientStorage
		}

		return .internalError
	}

	/// Handles completion of a `URLSessionDownloadTask` — moves the temp file to `localPath` and resumes the caller's continuation.
	private func handleDownloadCompletion(
		for urlSessionTask: URLSessionDownloadTask,
		finalUrl: URL?,
		response: URLResponse?,
		error: Error?
	) {
		downloadQueue.async { [weak self] in
			guard let self = self else { return }

			// Находим нашу задачу по URLSessionDownloadTask
			var taskKey: String?
			var downloadTask: DownloadTask?

			for (key, task) in self.activeDownloads {
				if task.downloadTask == urlSessionTask {
					taskKey = key
					downloadTask = task
					break
				}
			}

			guard let key = taskKey, let dlTask = downloadTask else {
				self.logger.error("📥 Не найдена задача загрузки для завершения")
				return
			}

			defer {
				// Очищаем активную загрузку
				self.activeDownloads.removeValue(forKey: key)
			}

			// Проверяем наличие ошибок
			if let error = error {
				self.logger.error("📥 Загрузка завершилась с ошибкой: \(error)")
				// Преобразуем системную ошибку в FileDownloadError
				let fileDownloadError = self.mapToFileDownloadError(error)
				dlTask.completion?(.failure(fileDownloadError))
				return
			}

			guard let finalUrl = finalUrl else {
				self.logger.error("📥 Загрузка завершена, но файл недоступен")
				dlTask.completion?(.failure(.noTempFile))
				return
			}

			// Файл уже перемещен в didFinishDownloadingTo
			self.logger.info("📥 Загрузка успешно завершена: \(finalUrl.path)")
			dlTask.completion?(.success(finalUrl))
		}
	}
}

// MARK: - URLSessionDownloadDelegate

extension FileDownloadService: URLSessionDownloadDelegate {

	public func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		// Находим соответствующую задачу загрузки
		downloadQueue.async { [weak self] in
			guard let self = self else { return }

			for (_, task) in self.activeDownloads {
				if task.downloadTask == downloadTask {
					let progress = totalBytesExpectedToWrite > 0
						? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
						: 0.0

					// Вызываем обработчик прогресса в главной очереди
					if let progressHandler = task.progressHandler {
						DispatchQueue.main.async {
							progressHandler(progress)
						}
					}
					break
				}
			}
		}
	}

	public func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) {
		logger.debug("📥 URLSession загрузка завершена в: \(location.path)")

		var finalUrl: URL?
		var moveError: Error?

		// Синхронно находим задачу и перемещаем файл
		downloadQueue.sync { [weak self] in
			guard let self = self else { return }

			// Находим задачу
			for (_, task) in self.activeDownloads {
				if task.downloadTask == downloadTask {
					// Проверяем HTTP статус-код ответа
					if let httpResponse = downloadTask.response as? HTTPURLResponse {
						let statusCode = httpResponse.statusCode

						if !(200...299).contains(statusCode) {
							self.logger.error("📥 Получен HTTP статус-код ошибки: \(statusCode)")
							moveError = self.mapToFileDownloadError(
								NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
							)
							// Не сохраняем файл с ошибкой
							break
						}
					}

					let targetUrl = URL(fileURLWithPath: task.localPath)

					do {
						// Перемещаем загруженный файл в финальное местоположение
						// AppFileManager уже содержит логику удаления существующего файла
						try self.appFileManager.moveItem(at: location, to: targetUrl)
						finalUrl = targetUrl
						self.logger.info("📥 Файл успешно перемещен: \(targetUrl.path)")

					} catch {
						self.logger.error("📥 Ошибка перемещения файла: \(error)")
						moveError = error
					}
					break
				}
			}
		}

		// Теперь асинхронно завершаем обработку
		handleDownloadCompletion(for: downloadTask, finalUrl: finalUrl, response: downloadTask.response, error: moveError)
	}

	public func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		if let downloadTask = task as? URLSessionDownloadTask, let error = error {
			logger.debug("📥 URLSession задача завершена с ошибкой: \(error)")
			handleDownloadCompletion(for: downloadTask, finalUrl: nil, response: task.response, error: error)
		}
	}
}

// MARK: - URLSessionDelegate

extension FileDownloadService {

	public func urlSession(
		_ session: URLSession,
		didBecomeInvalidWithError error: Error?
	) {
		if let error = error {
			logger.error("📥 URLSession стала недействительной: \(error)")
		}

		downloadQueue.async { [weak self] in
			guard let self = self else { return }

			// Завершаем все активные загрузки с ошибкой
			for (_, task) in self.activeDownloads {
				task.completion?(.failure(.internalError))
			}
			self.activeDownloads.removeAll()
		}
	}
}
