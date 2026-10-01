//
//  UserDefaultsKeyTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
@testable import InfraUserDefaults

@Suite("UserDefaultsKey")
struct UserDefaultsKeyTests {

	@Test("Raw values are unique")
	func uniqueRawValues() {
		let rawValues = UserDefaultsKey.allCases.map(\.rawValue)

		#expect(Set(rawValues).count == rawValues.count)
	}

	@Test("Every key has a non-empty description", arguments: UserDefaultsKey.allCases)
	func descriptions(key: UserDefaultsKey) {
		#expect(!key.description.isEmpty)
	}

	@Test("Only onboardingCompleted is critical", arguments: UserDefaultsKey.allCases)
	func criticality(key: UserDefaultsKey) {
		#expect(key.isCritical == (key == .onboardingCompleted))
	}

	@Test("Default values have the documented type", arguments: UserDefaultsKey.allCases)
	func defaultValueTypes(key: UserDefaultsKey) {
		switch key {
		case .onboardingCompleted:
			#expect(key.defaultValue as? Bool == false)
		case .recentProgramSearchQueries:
			#expect(key.defaultValue as? [String] == [])
		case .lastAppStartTime, .lastJwtSyncTime, .lastNewsSyncTime, .lastConferencesSyncTime,
			 .lastCertificatesSyncTime, .lastMessagesSyncTime, .lastSponsorsSyncTime, .lastClinicsSyncTime:
			#expect(key.defaultValue as? Int == 0)
		}
	}

	@Test("Every key belongs to a category with a non-empty description", arguments: UserDefaultsKey.allCases)
	func categories(key: UserDefaultsKey) {
		#expect(!key.category.description.isEmpty)
	}

	@Test("KeyCategory raw values are stable")
	func keyCategoryRawValues() {
		#expect(KeyCategory.allCases.map(\.rawValue) == ["application", "user", "cache", "dataBase"])
	}
}
