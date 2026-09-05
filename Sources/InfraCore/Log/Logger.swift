//
//  Logger.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import os.log

// MARK: - Logger Implementation
public final class Logger: ILogger {
	
	// MARK: - Properties
	private let minimumLogLevel: LogLevel
	private let enableConsoleLogging: Bool
	private let enableOSLogging: Bool
	/// Value-type timestamp formatter.
	///
	/// Deliberately not a `DateFormatter`: `createLogEntry` runs on the caller's thread,
	/// so a shared reference-type formatter is entered concurrently by every logging
	/// actor and queue in the host app, which corrupts its internal buffers.
	private let timestampStyle: Date.VerbatimFormatStyle
	private let logQueue: DispatchQueue
	private let subsystemPrefix: String
	private let exceptCategory: Set<LogCategory>

	// MARK: - Initialization
	public init(
		minimumLogLevel: LogLevel = .debug,
		enableConsoleLogging: Bool,
		enableOSLogging: Bool,
		queueLabel: String,
		subsystemPrefix: String,
		exceptCategory: Set<LogCategory> = []
	) {
		self.minimumLogLevel = minimumLogLevel
		self.enableConsoleLogging = enableConsoleLogging
		self.enableOSLogging = enableOSLogging
		self.logQueue = DispatchQueue(label: queueLabel, qos: .utility)
		self.subsystemPrefix = subsystemPrefix
		self.exceptCategory = exceptCategory

		self.timestampStyle = Date.VerbatimFormatStyle(
			format: "\(year: .padded(4))-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
			locale: Locale(identifier: "en_US_POSIX"),
			timeZone: .current,
			calendar: Calendar(identifier: .gregorian)
		)
	}
	
	// MARK: - Public Methods
	public func log(
		_ level: LogLevel,
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		guard shouldLog(level: level) else { return }
		
		let logEntry = createLogEntry(
			level: level,
			message: message,
			category: category,
			file: file,
			function: function,
			line: line
		)
		
		logQueue.async { [weak self] in
			self?.writeLog(entry: logEntry, level: level, category: category)
		}
	}
	
	public func verbose(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.verbose, message, category: category, file: file, function: function, line: line)
	}
	
	public func debug(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.debug, message, category: category, file: file, function: function, line: line)
	}
	
	public func info(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.info, message, category: category, file: file, function: function, line: line)
	}
	
	public func warning(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.warning, message, category: category, file: file, function: function, line: line)
	}
	
	public func error(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.error, message, category: category, file: file, function: function, line: line)
	}
	
	public func critical(
		_ message: String,
		category: LogCategory = .general,
		file: String = #file,
		function: String = #function,
		line: Int = #line
	) {
		log(.critical, message, category: category, file: file, function: function, line: line)
	}
}

// MARK: - Private Methods
private extension Logger {
	
	func shouldLog(level: LogLevel) -> Bool {
		let levels: [LogLevel] = [.verbose, .debug, .info, .warning, .error, .critical]
		guard let currentIndex = levels.firstIndex(of: level),
			  let minimumIndex = levels.firstIndex(of: minimumLogLevel) else {
			return false
		}
		return currentIndex >= minimumIndex
	}
	
	func createLogEntry(
		level: LogLevel,
		message: String,
		category: LogCategory,
		file: String,
		function: String,
		line: Int
	) -> String {
		let timestamp = timestampStyle.format(Date())
		let fileName = URL(fileURLWithPath: file).lastPathComponent
		
		return "[\(timestamp)] \(level.emoji) \(level.rawValue) [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)"
	}
	
	func writeLog(entry: String, level: LogLevel, category: LogCategory) {
		guard !exceptCategory.contains(category) else { return }
		
		if enableConsoleLogging {
			print(entry)
		}
		
		if enableOSLogging {
			writeToOSLog(entry: entry, level: level, category: category)
		}
	}
	
	func writeToOSLog(entry: String, level: LogLevel, category: LogCategory) {
		let subsystem = "\(subsystemPrefix).\(category.rawValue.lowercased())"
		let osLog = OSLog(subsystem: subsystem, category: category.rawValue)
		os_log("%{public}@", log: osLog, type: level.osLogType, entry)
	}
}

// MARK: - Logger Extensions for Convenience
public extension Logger {
	
	// MARK: - Network Logging
	func logNetworkRequest(url: String, method: String, headers: [String: String]? = nil) {
		let headersString = headers?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "No headers"
		info("🌐 REQUEST: \(method) \(url) | Headers: \(headersString)", category: .network)
	}
	
	func logNetworkResponse(url: String, statusCode: Int, responseTime: TimeInterval) {
		let status = statusCode >= 200 && statusCode < 300 ? "✅" : "❌"
		info("\(status) RESPONSE: \(url) | Status: \(statusCode) | Time: \(String(format: "%.2f", responseTime))s", category: .network)
	}
	
	func logNetworkError(url: String, error: Error) {
		self.error("🌐 NETWORK ERROR: \(url) | Error: \(error.localizedDescription)", category: .network)
	}
	
	// MARK: - UI Logging
	func logViewLifecycle(view: String, event: String) {
		debug("📱 \(view) - \(event)", category: .ui)
	}
	
	func logUserAction(action: String, context: String? = nil) {
		let contextString = context.map { " | Context: \($0)" } ?? ""
		info("👆 USER ACTION: \(action)\(contextString)", category: .ui)
	}
	
	// MARK: - Performance Logging
	func logPerformance(operation: String, duration: TimeInterval, metadata: [String: Any]? = nil) {
		let metadataString = metadata?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? ""
		let suffix = metadataString.isEmpty ? "" : " | Metadata: \(metadataString)"
		info("⚡ PERFORMANCE: \(operation) completed in \(String(format: "%.3f", duration))s\(suffix)", category: .performance)
	}
	
	// MARK: - Database Logging
	func logDatabaseOperation(operation: String, table: String? = nil, duration: TimeInterval? = nil) {
		let tableString = table.map { " on \($0)" } ?? ""
		let durationString = duration.map { " (\(String(format: "%.3f", $0))s)" } ?? ""
		debug("💾 DB: \(operation)\(tableString)\(durationString)", category: .database)
	}
	
	// MARK: - Security Logging
	func logSecurityEvent(event: String, level: LogLevel = .warning) {
		log(level, "⏺️ REPO: \(event)", category: .repository)
	}
}
