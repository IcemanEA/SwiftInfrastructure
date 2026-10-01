//
//  MockUserDefaultsRepositoryTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraUserDefaults
import InfraTestSupport

@Suite("MockUserDefaultsRepository")
struct MockUserDefaultsRepositoryTests {

	private let sut = MockUserDefaultsRepository()

	@Test("Falls back to the declared default when nothing is stored")
	func defaultFallback() {
		#expect(sut.getBool(for: .onboardingCompleted) == false)
		#expect(sut.getInt(for: .lastAppStartTime) == 0)
		#expect(sut.hasValue(for: .onboardingCompleted) == false)
	}

	@Test("Stored values round-trip and are reported by hasValue")
	func roundTrip() {
		sut.setValue(7, for: .lastAppStartTime)

		#expect(sut.getInt(for: .lastAppStartTime) == 7)
		#expect(sut.hasValue(for: .lastAppStartTime))
	}

	@Test("removeValue clears stored state and restores the default fallback")
	func removeValue() {
		sut.setValue(true, for: .onboardingCompleted)

		sut.removeValue(for: .onboardingCompleted)

		#expect(sut.hasValue(for: .onboardingCompleted) == false)
		#expect(sut.getBool(for: .onboardingCompleted) == false)
	}

	@Test("resetToDefaults discards every stored value")
	func resetToDefaults() {
		sut.setValue(true, for: .onboardingCompleted)
		sut.setValue(99.5, for: .lastJwtSyncTime)

		sut.resetToDefaults()

		#expect(sut.getBool(for: .onboardingCompleted) == false)
		#expect(sut.getDouble(for: .lastJwtSyncTime) == 0)
	}

	@Test("clearAllData discards every stored value and reports success")
	func clearAllData() {
		sut.setValue("x", for: .lastNewsSyncTime)

		#expect(sut.clearAllData())
		#expect(sut.hasValue(for: .lastNewsSyncTime) == false)
	}

	@Test("Typed getters coerce compatible values like the real repository")
	func coercion() {
		sut.setValue("yes", for: .onboardingCompleted)
		sut.setValue("abc", for: .lastAppStartTime)
		sut.setValue(42, for: .lastJwtSyncTime)
		sut.setValue(5, for: .lastNewsSyncTime)

		#expect(sut.getBool(for: .onboardingCompleted) == true)
		#expect(sut.getInt(for: .lastAppStartTime) == nil)
		#expect(sut.getDouble(for: .lastJwtSyncTime) == 42.0)
		#expect(sut.getString(for: .lastNewsSyncTime) == "5")
	}

	@Test("Values passed to init are readable immediately")
	func presetValues() {
		let preset = MockUserDefaultsRepository(values: [.recentProgramSearchQueries: ["a", "b"]])

		#expect(preset.getValue(for: .recentProgramSearchQueries) as? [String] == ["a", "b"])
	}
}
