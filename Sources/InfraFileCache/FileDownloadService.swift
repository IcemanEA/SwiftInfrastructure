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
/// reporting, pause, resume, and cancel support. The download table is
/// isolated to the actor; `URLSession` events reach it through a stateless
/// delegate, which moves each finished file into place before the system
/// deletes its temporary copy.
///
/// - `downloadFile` returns when the download finishes, fails or is cancelled.
///   A paused download keeps its callers waiting until it is resumed or cancelled.
/// - Cancelling the task that awaits `downloadFile` or `resumeDownload` releases
///   only that caller with ``FileDownloadError/internalError``; the download goes
///   on for any other caller. Use `cancelDownload` to stop the download itself.
/// - `resumeDownload` continues a download whose pause has completed, from the
///   server's resume data, or restarts it when the server provided none. A call
///   made while the pause is still in progress returns
///   ``FileDownloadError/downloadInProgress``. Its caller and the original
///   `downloadFile` caller both receive the final result.
/// - `cancelDownload` completes every waiting caller with
///   ``FileDownloadError/internalError``. A file that finishes moving into place
///   at the same moment is removed.
/// - `progressHandler` is called on the actor's executor, not on the main thread.
public actor FileDownloadService: IFileDownloadService {

	// MARK: - Вспомогательные типы

	private enum Phase {
		case running
		/// `cancelByProducingResumeData()` has been called and has not returned yet.
		case pausing
		case paused
	}

	private typealias Waiter = CheckedContinuation<Result<URL, FileDownloadError>, Never>

	private struct Download {
		let url: URL
		let localPath: String
		let progressHandler: (@Sendable (Double) -> Void)?
		var task: URLSessionDownloadTask
		var phase = Phase.running
		var resumeData: Data?
		var waiters: [UUID: Waiter] = [:]
	}

	// MARK: - Зависимости

	private let logger: LogManager
	private let session: URLSession
	private let events: AsyncStream<DownloadEvent>
	private let eventsContinuation: AsyncStream<DownloadEvent>.Continuation

	// MARK: - Управление состоянием

	private var downloads: [String: Download] = [:]
	private var eventLoop: Task<Void, Never>?

	// MARK: - Инициализация

	/// Creates the service with its own `URLSession`.
	///
	/// - Parameters:
	///   - logger: The sink for the service's log messages.
	///   - appFileManager: The file manager that moves finished downloads into place.
	///   - sessionConfiguration: The base configuration of the service's session. Timeouts,
	///     cellular access, connectivity waiting and the per-host connection limit are
	///     overridden on a copy. Pass a configuration with custom `protocolClasses` to
	///     serve requests without the network in tests.
	public init(
		logger: ILogger,
		appFileManager: IAppFileManager,
		sessionConfiguration: URLSessionConfiguration = .default
	) {
		let logger = LogManager(logger: logger, category: .files)

		// Настраиваем URL сессию для загрузок
		let configuration = sessionConfiguration.copy() as? URLSessionConfiguration ?? .default
		configuration.timeoutIntervalForRequest = 30.0
		configuration.timeoutIntervalForResource = 300.0 // 5 минут
		configuration.allowsCellularAccess = true
		configuration.waitsForConnectivity = true
		configuration.httpMaximumConnectionsPerHost = 4

		let (events, eventsContinuation) = AsyncStream.makeStream(of: DownloadEvent.self)
		let delegate = DownloadSessionDelegate(
			events: eventsContinuation,
			appFileManager: appFileManager,
			logger: logger
		)

		self.logger = logger
		self.events = events
		self.eventsContinuation = eventsContinuation
		self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
	}

	deinit {
		session.invalidateAndCancel()
		eventsContinuation.finish()
	}

	// MARK: - IFileDownloadService Implementation

	public func downloadFile(
		from url: URL,
		to localPath: String,
		progressHandler: (@Sendable (Double) -> Void)?
	) async -> Result<URL, FileDownloadError> {
		logger.info("📥 Начало загрузки: \(url.absoluteString) → \(localPath)")

		let key = makeKey(url: url, localPath: localPath)

		// Проверяем, не выполняется ли уже загрузка
		guard downloads[key] == nil else {
			return .failure(.downloadInProgress)
		}

		startEventLoopIfNeeded()

		let task = makeTask(url: url, resumeData: nil, localPath: localPath)
		downloads[key] = Download(url: url, localPath: localPath, progressHandler: progressHandler, task: task)
		logger.info("📥 Задача загрузки запущена для: \(url.absoluteString)")

		return await wait(for: key, starting: task)
	}

	public func pauseDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let key = makeKey(url: url, localPath: localPath)

		guard let download = downloads[key] else {
			return .failure(.taskNotFound)
		}
		guard download.phase == .running else {
			return .success(())
		}

		// Помечаем паузу до отмены задачи, чтобы событие отмены не завершило ожидающих.
		downloads[key]?.phase = .pausing

		let resumeData = await download.task.cancelByProducingResumeData()

		// Пока ждали данные, загрузка могла завершиться или быть отменена.
		guard downloads[key]?.phase == .pausing else {
			return .success(())
		}
		downloads[key]?.phase = .paused
		downloads[key]?.resumeData = resumeData
		logger.info("📥 Загрузка приостановлена: \(url.absoluteString)")
		return .success(())
	}

	public func resumeDownload(url: URL, localPath: String) async -> Result<URL, FileDownloadError> {
		let key = makeKey(url: url, localPath: localPath)

		guard var download = downloads[key] else {
			return .failure(.noResumeData)
		}
		guard download.phase == .paused else {
			return .failure(.downloadInProgress)
		}

		startEventLoopIfNeeded()

		let task = makeTask(url: url, resumeData: download.resumeData, localPath: localPath)
		download.task = task
		download.phase = .running
		download.resumeData = nil
		downloads[key] = download
		logger.info("📥 Загрузка возобновлена: \(url.absoluteString)")

		return await wait(for: key, starting: task)
	}

	public func cancelDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError> {
		let key = makeKey(url: url, localPath: localPath)

		guard let download = downloads.removeValue(forKey: key) else {
			return .failure(.taskNotFound)
		}

		download.task.cancel()
		for waiter in download.waiters.values {
			waiter.resume(returning: .failure(.internalError))
		}

		logger.info("📥 Загрузка отменена: \(url.absoluteString)")
		return .success(())
	}

	public func getDownloadProgress(url: URL, localPath: String) async -> Double? {
		downloads[makeKey(url: url, localPath: localPath)]?.task.progress.fractionCompleted
	}

	// MARK: - Приватные методы

	/// Builds the stable key used to deduplicate concurrent downloads of the same `(url, localPath)` pair.
	private func makeKey(url: URL, localPath: String) -> String {
		"\(url.absoluteString)|\(localPath)"
	}

	/// Registers the caller, starts `task`, and suspends until the download under `key` completes
	/// or the caller's task is cancelled.
	///
	/// The task starts only after the caller is registered, so even an instant completion finds it.
	private func wait(for key: String, starting task: URLSessionDownloadTask) async -> Result<URL, FileDownloadError> {
		let id = UUID()
		return await withTaskCancellationHandler {
			await withCheckedContinuation { continuation in
				guard downloads[key] != nil else {
					continuation.resume(returning: .failure(.internalError))
					return
				}
				downloads[key]?.waiters[id] = continuation
				task.resume()

				// Отмена могла прийти до регистрации ожидающего.
				if Task.isCancelled {
					releaseWaiter(id, of: key)
				}
			}
		} onCancel: {
			Task { [weak self] in
				await self?.releaseWaiter(id, of: key)
			}
		}
	}

	/// Completes one cancelled caller; the download itself continues.
	private func releaseWaiter(_ id: UUID, of key: String) {
		guard let waiter = downloads[key]?.waiters.removeValue(forKey: id) else { return }
		waiter.resume(returning: .failure(.internalError))
	}

	/// Creates a session task whose description carries the destination path for the delegate.
	private func makeTask(url: URL, resumeData: Data?, localPath: String) -> URLSessionDownloadTask {
		let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: url)
		task.taskDescription = localPath
		return task
	}

	private func startEventLoopIfNeeded() {
		guard eventLoop == nil else { return }

		eventLoop = Task { [weak self, events] in
			for await event in events {
				await self?.handle(event)
			}
		}
	}

	private func handle(_ event: DownloadEvent) {
		guard let key = downloads.first(where: { $0.value.task.taskIdentifier == event.taskIdentifier })?.key,
			  let download = downloads[key] else {
			removeOrphanedFile(of: event)
			return
		}

		switch event.kind {
		case .progress(let fraction):
			download.progressHandler?(fraction)

		case .finished(let result):
			downloads[key] = nil
			if case .success(let fileUrl) = result {
				logger.info("📥 Загрузка успешно завершена: \(fileUrl.path)")
			}
			for waiter in download.waiters.values {
				waiter.resume(returning: result)
			}

		case .failed(let error):
			// Отмена задачи при паузе — не ошибка загрузки.
			guard download.phase == .running else { return }

			logger.error("📥 Загрузка завершилась с ошибкой: \(error)")
			downloads[key] = nil
			for waiter in download.waiters.values {
				waiter.resume(returning: .failure(error))
			}
		}
	}

	/// Removes a file that a cancelled download moved into place after it was cancelled,
	/// unless another download now targets the same path.
	private func removeOrphanedFile(of event: DownloadEvent) {
		guard case .finished(.success(let fileUrl)) = event.kind,
			  !downloads.values.contains(where: { URL(fileURLWithPath: $0.localPath) == fileUrl }) else {
			return
		}
		try? FileManager.default.removeItem(at: fileUrl)
		logger.info("📥 Удален файл отмененной загрузки: \(fileUrl.path)")
	}
}

// MARK: - Session events

/// An event the session delegate forwards to the service.
struct DownloadEvent: Sendable {

	enum Kind: Sendable {
		case progress(Double)
		case finished(Result<URL, FileDownloadError>)
		case failed(FileDownloadError)
	}

	let taskIdentifier: Int
	let kind: Kind
}

/// Receives `URLSession` callbacks and forwards them as ``DownloadEvent`` values.
///
/// Holds no mutable state. The finished file is moved synchronously inside
/// `didFinishDownloadingTo`, because the system deletes the temporary file as
/// soon as that method returns; the destination comes from the task's
/// `taskDescription`, set by the service before the task starts.
final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, Sendable {

	private let events: AsyncStream<DownloadEvent>.Continuation
	private let appFileManager: IAppFileManager
	private let logger: LogManager

	init(events: AsyncStream<DownloadEvent>.Continuation, appFileManager: IAppFileManager, logger: LogManager) {
		self.events = events
		self.appFileManager = appFileManager
		self.logger = logger
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		let progress = totalBytesExpectedToWrite > 0
			? min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1.0)
			: 0.0
		events.yield(DownloadEvent(taskIdentifier: downloadTask.taskIdentifier, kind: .progress(progress)))
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) {
		logger.debug("📥 URLSession загрузка завершена в: \(location.path)")
		events.yield(DownloadEvent(taskIdentifier: downloadTask.taskIdentifier, kind: .finished(moveFile(of: downloadTask, from: location))))
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		guard let error else { return }

		logger.debug("📥 URLSession задача завершена с ошибкой: \(error)")
		events.yield(DownloadEvent(taskIdentifier: task.taskIdentifier, kind: .failed(FileDownloadError(mapping: error))))
	}

	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		if let error {
			logger.error("📥 URLSession стала недействительной: \(error)")
		}
	}

	// MARK: - Private Methods

	/// Moves the temporary file to the task's destination, or explains why it was not kept.
	private func moveFile(of downloadTask: URLSessionDownloadTask, from location: URL) -> Result<URL, FileDownloadError> {
		// Проверяем HTTP статус-код ответа
		if let httpResponse = downloadTask.response as? HTTPURLResponse,
		   !(200...299).contains(httpResponse.statusCode) {
			logger.error("📥 Получен HTTP статус-код ошибки: \(httpResponse.statusCode)")
			return .failure(.serverError(statusCode: httpResponse.statusCode))
		}

		guard let localPath = downloadTask.taskDescription else {
			logger.error("📥 Не задан путь назначения для загрузки")
			return .failure(.noTempFile)
		}

		let targetUrl = URL(fileURLWithPath: localPath)
		do {
			// AppFileManager уже содержит логику удаления существующего файла
			try appFileManager.moveItem(at: location, to: targetUrl)
			logger.info("📥 Файл успешно перемещен: \(targetUrl.path)")
			return .success(targetUrl)
		} catch {
			logger.error("📥 Ошибка перемещения файла: \(error)")
			return .failure(FileDownloadError(mapping: error))
		}
	}
}

// MARK: - Error mapping

extension FileDownloadError {

	/// Maps a system `Error` into the library's ``FileDownloadError`` domain.
	init(mapping error: Error) {
		if let urlError = error as? URLError {
			switch urlError.code {
			case .notConnectedToInternet, .networkConnectionLost:
				self = .noInternetConnection
			case .timedOut:
				self = .timeout
			case .unsupportedURL, .badURL:
				self = .invalidUrl
			case .httpTooManyRedirects, .badServerResponse:
				self = .serverError(statusCode: urlError.errorCode)
			default:
				self = .internalError
			}
		} else if (error as NSError).domain == NSPOSIXErrorDomain && (error as NSError).code == 28 { // ENOSPC
			self = .insufficientStorage
		} else {
			self = .internalError
		}
	}
}
