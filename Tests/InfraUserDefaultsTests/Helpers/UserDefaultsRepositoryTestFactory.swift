//
//  UserDefaultsRepositoryTestFactory.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import InfraUserDefaults

/// A repository over a private, uniquely named `UserDefaults` suite.
struct IsolatedUserDefaults {
	let suiteName: String
	let defaults: UserDefaults

	/// Removes the suite's persistent domain so nothing is left behind.
	func cleanUp() {
		defaults.removePersistentDomain(forName: suiteName)
	}
}

enum UserDefaultsRepositoryTestFactory {
	/// Creates an empty suite with a unique name. Pre-populate it before calling `makeRepository(over:)` to test seeding.
	static func makeSuite() -> IsolatedUserDefaults {
		let suiteName = "InfraUserDefaultsTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		return IsolatedUserDefaults(suiteName: suiteName, defaults: defaults)
	}

	static func makeRepository(over suite: IsolatedUserDefaults) -> UserDefaultsRepository {
		UserDefaultsRepository(userDefaults: suite.defaults)
	}
}
