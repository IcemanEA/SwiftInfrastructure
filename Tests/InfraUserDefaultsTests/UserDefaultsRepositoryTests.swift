//
//  UserDefaultsRepositoryTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
@testable import InfraUserDefaults

@Suite("UserDefaultsRepository")
struct UserDefaultsRepositoryTests {

	private let suite = UserDefaultsRepositoryTestFactory.makeSuite()

	// MARK: - Isolation

	@Test("The test suite leaves no values behind after cleanup")
	func cleanupRemovesSuite() {
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)
		sut.setValue(true, for: .onboardingCompleted)

		suite.cleanUp()

		#expect(UserDefaults(suiteName: suite.suiteName)?.object(forKey: UserDefaultsKey.onboardingCompleted.rawValue) == nil)
	}

	// MARK: - Default seeding

	@Test("A fresh suite is seeded with every declared default")
	func freshSuiteIsSeeded() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		for key in UserDefaultsKey.allCases where key.defaultValue != nil {
			#expect(sut.hasValue(for: key), "\(key) should be seeded")
		}
		#expect(sut.getBool(for: .onboardingCompleted) == false)
		#expect(sut.getInt(for: .lastAppStartTime) == 0)
		#expect(sut.getValue(for: .recentProgramSearchQueries) as? [String] == [])
	}

	@Test("An existing value survives construction")
	func existingValueSurvives() {
		defer { suite.cleanUp() }
		suite.defaults.set(true, forKey: UserDefaultsKey.onboardingCompleted.rawValue)

		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		#expect(sut.getBool(for: .onboardingCompleted) == true)
	}

	// MARK: - hasValue / removeValue

	@Test("Removal clears stored state but not the default fallback")
	func removalKeepsFallback() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.removeValue(for: .lastNewsSyncTime)

		#expect(sut.hasValue(for: .lastNewsSyncTime) == false)
		#expect(sut.getValue(for: .lastNewsSyncTime) as? Int == 0)
	}

	@Test("Removing a critical key works the same way")
	func removeCriticalKey() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)
		sut.setValue(true, for: .onboardingCompleted)

		sut.removeValue(for: .onboardingCompleted)

		#expect(sut.hasValue(for: .onboardingCompleted) == false)
		#expect(sut.getBool(for: .onboardingCompleted) == false)
	}

	// MARK: - resetToDefaults

	@Test("resetToDefaults replaces custom values with defaults")
	func resetRestoresDefaults() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)
		sut.setValue(true, for: .onboardingCompleted)
		sut.setValue(["swift"], for: .recentProgramSearchQueries)

		sut.resetToDefaults()

		#expect(sut.getBool(for: .onboardingCompleted) == false)
		#expect(sut.getValue(for: .recentProgramSearchQueries) as? [String] == [])
		#expect(sut.hasValue(for: .onboardingCompleted))
	}

	// MARK: - Round trips

	@Test("Values of every supported type round-trip")
	func roundTrips() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue("text", for: .lastNewsSyncTime)
		sut.setValue(true, for: .onboardingCompleted)
		sut.setValue(17, for: .lastAppStartTime)
		sut.setValue(1.5, for: .lastJwtSyncTime)
		sut.setValue(["a", "b"], for: .recentProgramSearchQueries)

		#expect(sut.getString(for: .lastNewsSyncTime) == "text")
		#expect(sut.getBool(for: .onboardingCompleted) == true)
		#expect(sut.getInt(for: .lastAppStartTime) == 17)
		#expect(sut.getDouble(for: .lastJwtSyncTime) == 1.5)
		#expect(sut.getValue(for: .recentProgramSearchQueries) as? [String] == ["a", "b"])
	}

	@Test("Writes are visible in the backing suite")
	func writesReachBackingStore() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue(99, for: .lastClinicsSyncTime)

		#expect(suite.defaults.integer(forKey: UserDefaultsKey.lastClinicsSyncTime.rawValue) == 99)
	}

	// MARK: - Coercion

	@Test("String values coerce to Bool", arguments: [
		("true", true), ("YES", true), ("1", true),
		("false", false), ("no", false), ("0", false)
	])
	func stringToBool(stored: String, expected: Bool) {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue(stored, for: .onboardingCompleted)

		#expect(sut.getBool(for: .onboardingCompleted) == expected)
	}

	@Test("An unrecognized string does not coerce to Bool")
	func unrecognizedStringToBool() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue("maybe", for: .onboardingCompleted)

		#expect(sut.getBool(for: .onboardingCompleted) == nil)
	}

	@Test("A non-numeric string does not coerce to Int")
	func nonNumericStringToInt() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue("abc", for: .lastAppStartTime)

		#expect(sut.getInt(for: .lastAppStartTime) == nil)
	}

	@Test("Numeric strings coerce to Int and Double")
	func numericStrings() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue("12", for: .lastAppStartTime)
		sut.setValue("2.5", for: .lastJwtSyncTime)

		#expect(sut.getInt(for: .lastAppStartTime) == 12)
		#expect(sut.getDouble(for: .lastJwtSyncTime) == 2.5)
	}

	@Test("Int coerces to Double and numbers coerce to String")
	func numberCoercion() {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		sut.setValue(42, for: .lastJwtSyncTime)

		#expect(sut.getDouble(for: .lastJwtSyncTime) == 42.0)
		#expect(sut.getString(for: .lastJwtSyncTime) == "42")
	}

	// MARK: - Concurrency

	@Test("Concurrent writes and reads do not crash and the last write is readable")
	func concurrentAccess() async {
		defer { suite.cleanUp() }
		let sut = UserDefaultsRepositoryTestFactory.makeRepository(over: suite)

		await withTaskGroup(of: Void.self) { group in
			for index in 0..<200 {
				group.addTask {
					sut.setValue(index, for: .lastMessagesSyncTime)
					_ = sut.getInt(for: .lastMessagesSyncTime)
				}
			}
		}
		sut.setValue(-1, for: .lastMessagesSyncTime)

		#expect(sut.getInt(for: .lastMessagesSyncTime) == -1)
	}
}
