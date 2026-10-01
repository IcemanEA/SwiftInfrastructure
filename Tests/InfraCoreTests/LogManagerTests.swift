//
//  LogManagerTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraCore
import InfraTestSupport

@Suite("LogManager")
struct LogManagerTests {

	private let logger = MockLogger()

	@Test("Every proxy method forwards its level, message and the bound category", arguments: LogLevel.allCases, LogCategory.allCases)
	func forwardsLevelAndCategory(level: LogLevel, category: LogCategory) {
		let sut = LogManager(logger: logger, category: category)

		switch level {
		case .verbose: sut.verbose("message")
		case .debug: sut.debug("message")
		case .info: sut.info("message")
		case .warning: sut.warning("message")
		case .error: sut.error("message")
		case .critical: sut.critical("message")
		}

		#expect(logger.entries == [MockLogger.Entry(level: level, message: "message", category: category)])
	}
}
