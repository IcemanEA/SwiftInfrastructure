//
//  LoggerTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import OSLog
@testable import InfraCore

@Suite("Logger")
struct LoggerTests {

	@Test("A silent logger accepts calls at every level and category", arguments: LogLevel.allCases)
	func silentLoggerAcceptsCalls(minimumLevel: LogLevel) {
		let sut = InfraCore.Logger(
			minimumLogLevel: minimumLevel,
			enableConsoleLogging: false,
			enableOSLogging: false,
			queueLabel: "InfraCoreTests.logger",
			subsystemPrefix: "com.example.tests",
			exceptCategory: [.ui]
		)

		for category in LogCategory.allCases {
			sut.verbose("v", category: category)
			sut.debug("d", category: category)
			sut.info("i", category: category)
			sut.warning("w", category: category)
			sut.error("e", category: category)
			sut.critical("c", category: category)
		}
	}

	@Test("Each level maps to its emoji and OSLog type", arguments: [
		(LogLevel.verbose, "💬", OSLogType.debug),
		(.debug, "🐛", .debug),
		(.info, "ℹ️", .info),
		(.warning, "⚠️", .default),
		(.error, "❌", .error),
		(.critical, "💥", .fault)
	])
	func levelMapping(level: LogLevel, emoji: String, osLogType: OSLogType) {
		#expect(level.emoji == emoji)
		#expect(level.osLogType == osLogType)
	}

	@Test("Level raw values are stable")
	func levelRawValues() {
		#expect(LogLevel.allCases.map(\.rawValue) == ["VERBOSE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"])
	}

	@Test("Category raw values are stable")
	func categoryRawValues() {
		#expect(LogCategory.allCases.map(\.rawValue) == [
			"NETWORK", "DATABASE", "FILES", "UI", "BUSINESS", "REPO", "PERFORMANCE", "LIFECYCLE", "GENERAL"
		])
	}
}
