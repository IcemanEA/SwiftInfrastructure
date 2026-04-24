//
//  MockUserDefaultsRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 24.06.2025.
//

import Foundation
import InfraUserDefaults

public final class MockUserDefaultsRepository: IUserDefaultsRepository {

	public init() {}

	public func getValue(for key: UserDefaultsKey) -> Any? {
		nil
	}

	public func setValue(_ value: Any?, for key: UserDefaultsKey) {

	}

	public func removeValue(for key: UserDefaultsKey) {

	}

	public func getString(for key: UserDefaultsKey) -> String? {
		nil
	}

	public func getBool(for key: UserDefaultsKey) -> Bool? {
		nil
	}

	public func getInt(for key: UserDefaultsKey) -> Int? {
		nil
	}

	public func getDouble(for key: UserDefaultsKey) -> Double? {
		nil
	}

	public func hasValue(for key: UserDefaultsKey) -> Bool {
		false
	}

	public func resetToDefaults() {

	}

	public func synchronize() {

	}

	public func clearAllData() -> Bool {
		return true
	}
}
