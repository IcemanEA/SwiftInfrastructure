//
//  MockLogger.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import InfraCore

/// A recording ``ILogger`` for tests that need to assert on log calls.
///
/// ## Overview
///
/// Every call is appended to ``entries`` as an ``Entry`` holding the level,
/// message, and category. Nothing is printed and nothing is written to OSLog.
/// Access is guarded by a lock, so the mock is safe to share across tasks and
/// queues.
///
/// ```swift
/// let logger = MockLogger()
/// let service = AppFileManager(logger: logger)
/// // … exercise the service …
/// #expect(logger.entries.contains { $0.level == .error })
/// ```
public final class MockLogger: ILogger, @unchecked Sendable {

	/// A single recorded log call.
	public struct Entry: Equatable, Sendable {
		/// The severity level of the call.
		public let level: LogLevel
		/// The message text of the call.
		public let message: String
		/// The category passed with the call.
		public let category: LogCategory

		public init(level: LogLevel, message: String, category: LogCategory) {
			self.level = level
			self.message = message
			self.category = category
		}
	}

	private let lock = NSLock()
	private var storage: [Entry] = []

	public init() {}

	/// Every recorded call, in the order it was made.
	public var entries: [Entry] {
		lock.lock()
		defer { lock.unlock() }
		return storage
	}

	/// Removes every recorded entry.
	public func reset() {
		lock.lock()
		defer { lock.unlock() }
		storage.removeAll()
	}

	// MARK: - ILogger

	public func log(
		_ level: LogLevel,
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		lock.lock()
		defer { lock.unlock() }
		storage.append(Entry(level: level, message: message, category: category))
	}

	public func verbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.verbose, message, category: category, file: file, function: function, line: line)
	}

	public func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.debug, message, category: category, file: file, function: function, line: line)
	}

	public func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.info, message, category: category, file: file, function: function, line: line)
	}

	public func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.warning, message, category: category, file: file, function: function, line: line)
	}

	public func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.error, message, category: category, file: file, function: function, line: line)
	}

	public func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
		log(.critical, message, category: category, file: file, function: function, line: line)
	}
}
