//
//  LockedStateTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Testing
import InfraTestSupport

@Suite("LockedState")
struct LockedStateTests {

	@Test("Concurrent increments are not lost")
	func concurrentIncrements() async {
		let sut = LockedState(0)

		await withTaskGroup(of: Void.self) { group in
			for _ in 0..<1000 {
				group.addTask {
					sut.withLock { $0 += 1 }
				}
			}
		}

		#expect(sut.withLock { $0 } == 1000)
	}

	@Test("Returns the closure's result and keeps the mutation")
	func returnsResult() {
		let sut = LockedState([1, 2])

		let count = sut.withLock { value -> Int in
			value.append(3)
			return value.count
		}

		#expect(count == 3)
		#expect(sut.withLock { $0 } == [1, 2, 3])
	}

	@Test("A thrown error propagates and releases the lock")
	func errorPropagates() {
		struct Failure: Error {}
		let sut = LockedState(0)

		#expect(throws: Failure.self) {
			try sut.withLock { _ in throw Failure() }
		}
		#expect(sut.withLock { $0 } == 0)
	}
}
