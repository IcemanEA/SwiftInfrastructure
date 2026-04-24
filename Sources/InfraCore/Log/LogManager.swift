//
//  LogManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

public final class LogManager {
	private let logger: ILogger
	private let category: LogCategory
	
	public init(logger: ILogger, category: LogCategory) {
		self.logger = logger
		self.category = category
	}
	
	// Proxy all logger methods with predefined category
	public func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.verbose(message, category: category, file: file, function: function, line: line)
	}
	
	public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.debug(message, category: category, file: file, function: function, line: line)
	}
	
	public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.info(message, category: category, file: file, function: function, line: line)
	}
	
	public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.warning(message, category: category, file: file, function: function, line: line)
	}
	
	public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.error(message, category: category, file: file, function: function, line: line)
	}
	
	public func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
		logger.critical(message, category: category, file: file, function: function, line: line)
	}
}
