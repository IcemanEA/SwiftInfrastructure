//
//  MockLoggerTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraCore
import InfraTestSupport

@Suite("MockLogger")
struct MockLoggerTests {

	@Test("Records entries in call order with level, message and category")
	func recordsEntriesInOrder() {
		let sut = MockLogger()

		sut.info("a", category: .network)
		sut.error("b", category: .database)

		#expect(sut.entries == [
			MockLogger.Entry(level: .info, message: "a", category: .network),
			MockLogger.Entry(level: .error, message: "b", category: .database)
		])
	}

	@Test("Records calls made through LogManager with the bound category")
	func recordsThroughLogManager() {
		let sut = MockLogger()
		let manager = LogManager(logger: sut, category: .files)

		manager.warning("x")

		#expect(sut.entries == [MockLogger.Entry(level: .warning, message: "x", category: .files)])
	}

	@Test("Each convenience method records its own level", arguments: LogLevel.allCases)
	func convenienceMethodsMapToLevel(level: LogLevel) {
		let sut = MockLogger()

		switch level {
		case .verbose: sut.verbose("m")
		case .debug: sut.debug("m")
		case .info: sut.info("m")
		case .warning: sut.warning("m")
		case .error: sut.error("m")
		case .critical: sut.critical("m")
		}

		#expect(sut.entries == [MockLogger.Entry(level: level, message: "m", category: .general)])
	}

	@Test("reset removes every recorded entry")
	func resetClearsEntries() {
		let sut = MockLogger()
		sut.info("a")

		sut.reset()

		#expect(sut.entries.isEmpty)
	}

	@Test("Concurrent calls are all recorded")
	func concurrentCallsAreRecorded() async {
		let sut = MockLogger()

		await withTaskGroup(of: Void.self) { group in
			for index in 0..<100 {
				group.addTask { sut.debug("\(index)") }
			}
		}

		#expect(sut.entries.count == 100)
	}
}
