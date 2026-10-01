//
//  MockUserDefaultsRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 24.06.2025.
//

import Foundation
import InfraUserDefaults

/// An in-memory ``IUserDefaultsRepository`` for tests and previews.
///
/// ## Overview
///
/// Stores values in a lock-guarded dictionary and never touches a
/// `UserDefaults` instance. Reads fall back to each key's
/// `UserDefaultsKey.defaultValue` when nothing is stored, and the typed
/// getters apply the same coercion rules as `UserDefaultsRepository`.
/// Unlike the real repository, the mock does not seed defaults into its
/// store, so ``hasValue(for:)`` reports only values written through the mock.
///
/// ```swift
/// let repository = MockUserDefaultsRepository()
/// repository.setValue(true, for: .onboardingCompleted)
/// #expect(repository.getBool(for: .onboardingCompleted) == true)
/// ```
public final class MockUserDefaultsRepository: IUserDefaultsRepository, @unchecked Sendable {

	private let lock = NSLock()
	private var storage: [UserDefaultsKey: Any] = [:]

	/// Creates the mock, optionally pre-seeded with values.
	///
	/// - Parameter values: Values to store before the first read, keyed by ``UserDefaultsKey``.
	public init(values: [UserDefaultsKey: Any] = [:]) {
		self.storage = values
	}

	// MARK: - Generic Methods

	public func getValue(for key: UserDefaultsKey) -> Any? {
		lock.lock()
		defer { lock.unlock() }
		return storage[key] ?? key.defaultValue
	}

	public func setValue(_ value: Any?, for key: UserDefaultsKey) {
		lock.lock()
		defer { lock.unlock() }
		storage[key] = value
	}

	public func removeValue(for key: UserDefaultsKey) {
		lock.lock()
		defer { lock.unlock() }
		storage.removeValue(forKey: key)
	}

	// MARK: - Typed Methods

	public func getString(for key: UserDefaultsKey) -> String? {
		guard let value = getValue(for: key) else { return nil }
		if let stringValue = value as? String {
			return stringValue
		}
		if let numberValue = value as? NSNumber {
			return numberValue.stringValue
		}
		return String(describing: value)
	}

	public func getBool(for key: UserDefaultsKey) -> Bool? {
		guard let value = getValue(for: key) else { return nil }
		if let boolValue = value as? Bool {
			return boolValue
		}
		if let numberValue = value as? NSNumber {
			return numberValue.boolValue
		}
		if let stringValue = value as? String {
			switch stringValue.lowercased() {
			case "true", "yes", "1":
				return true
			case "false", "no", "0":
				return false
			default:
				return nil
			}
		}
		return nil
	}

	public func getInt(for key: UserDefaultsKey) -> Int? {
		guard let value = getValue(for: key) else { return nil }
		if let intValue = value as? Int {
			return intValue
		}
		if let numberValue = value as? NSNumber {
			return numberValue.intValue
		}
		if let stringValue = value as? String, let intValue = Int(stringValue) {
			return intValue
		}
		return nil
	}

	public func getDouble(for key: UserDefaultsKey) -> Double? {
		guard let value = getValue(for: key) else { return nil }
		if let doubleValue = value as? Double {
			return doubleValue
		}
		if let numberValue = value as? NSNumber {
			return numberValue.doubleValue
		}
		if let stringValue = value as? String, let doubleValue = Double(stringValue) {
			return doubleValue
		}
		return nil
	}

	// MARK: - Utility Methods

	public func hasValue(for key: UserDefaultsKey) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return storage[key] != nil
	}

	public func resetToDefaults() {
		lock.lock()
		defer { lock.unlock() }
		storage.removeAll()
	}

	public func synchronize() {

	}

	public func clearAllData() -> Bool {
		lock.lock()
		defer { lock.unlock() }
		storage.removeAll()
		return true
	}
}
