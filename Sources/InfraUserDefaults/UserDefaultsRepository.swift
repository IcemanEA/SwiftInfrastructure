//
//  UserDefaultsRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 24.06.2025.
//

import Foundation

/// The concrete ``IUserDefaultsRepository`` implementation backed by a `UserDefaults` instance.
///
/// ## Overview
///
/// Provides a thread-safe, typed facade over `UserDefaults` that honours the
/// default values declared by each ``UserDefaultsKey`` case and automatically
/// flushes writes for keys marked `isCritical`.
///
/// ```swift
/// // Production:
/// let repo = UserDefaultsRepository()
///
/// // Tests:
/// let repo = UserDefaultsRepository(suiteName: "test")
///
/// // App Groups:
/// let repo = UserDefaultsRepository(suiteName: "group.com.example.myapp")
/// ```
public final class UserDefaultsRepository: IUserDefaultsRepository, Sendable {

	// MARK: - Properties

	/// Name of the `UserDefaults` suite backing this repository; `nil` means `.standard`.
	private let suiteName: String?

	/// The underlying store, resolved on every access.
	///
	/// Not stored: `UserDefaults` is not `Sendable`, so a stored instance would
	/// make this repository non-`Sendable`. `UserDefaults` itself is thread-safe.
	private var userDefaults: UserDefaults {
		guard let suiteName else { return .standard }
		return UserDefaults(suiteName: suiteName) ?? .standard
	}

	/// Serial queue that guards access to `userDefaults` for thread-safe reads and writes.
	private let queue = DispatchQueue(label: "infra.userdefaults.queue", qos: .utility)

	// MARK: - Initialization

	/// Creates the repository over a `UserDefaults` suite.
	///
	/// - Parameter suiteName: Name of the suite to use. `nil` selects `UserDefaults.standard`.
	/// - Precondition: `UserDefaults(suiteName:)` accepts the name; the app's bundle identifier
	///   and `NSGlobalDomain` are rejected by the system.
	public init(suiteName: String? = nil) {
		if let suiteName {
			precondition(UserDefaults(suiteName: suiteName) != nil, "Invalid UserDefaults suite name: \(suiteName)")
		}
		self.suiteName = suiteName

		// Выполняем первоначальную инициализацию
		setupDefaultValues()
	}
	
	// MARK: - Generic Methods
	
	public func getValue(for key: UserDefaultsKey) -> Any? {
		return queue.sync {
			let value = userDefaults.object(forKey: key.rawValue)
			
			// Если значение отсутствует, возвращаем значение по умолчанию
			if value == nil, let defaultValue = key.defaultValue {
				return defaultValue
			}
			
			return value
		}
	}
	
	public func setValue(_ value: Any?, for key: UserDefaultsKey) {
		queue.sync {
			userDefaults.set(value, forKey: key.rawValue)
			
			// Для критичных ключей принудительно синхронизируем
			if key.isCritical {
				userDefaults.synchronize()
			}
		}
	}
	
	public func removeValue(for key: UserDefaultsKey) {
		queue.sync {
			userDefaults.removeObject(forKey: key.rawValue)
			
			// Для критичных ключей принудительно синхронизируем
			if key.isCritical {
				userDefaults.synchronize()
			}
		}
	}
	
	// MARK: - Typed Methods
	
	public func getString(for key: UserDefaultsKey) -> String? {
		guard let value = getValue(for: key) else { return nil }
		
		// Безопасное приведение к String
		if let stringValue = value as? String {
			return stringValue
		}
		
		// Попытка преобразования из других типов
		if let numberValue = value as? NSNumber {
			return numberValue.stringValue
		}
		
		return String(describing: value)
	}
	
	public func getBool(for key: UserDefaultsKey) -> Bool? {
		guard let value = getValue(for: key) else { return nil }
		
		// Безопасное приведение к Bool
		if let boolValue = value as? Bool {
			return boolValue
		}
		
		// Попытка преобразования из других типов
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
		
		// Безопасное приведение к Int
		if let intValue = value as? Int {
			return intValue
		}
		
		// Попытка преобразования из других типов
		if let numberValue = value as? NSNumber {
			return numberValue.intValue
		}
		
		if let stringValue = value as? String, let intValue = Int(stringValue) {
			return intValue
		}
		
		if let doubleValue = value as? Double {
			return Int(doubleValue)
		}
		
		return nil
	}
	
	public func getDouble(for key: UserDefaultsKey) -> Double? {
		guard let value = getValue(for: key) else { return nil }
		
		// Безопасное приведение к Double
		if let doubleValue = value as? Double {
			return doubleValue
		}
		
		// Попытка преобразования из других типов
		if let numberValue = value as? NSNumber {
			return numberValue.doubleValue
		}
		
		if let stringValue = value as? String, let doubleValue = Double(stringValue) {
			return doubleValue
		}
		
		if let intValue = value as? Int {
			return Double(intValue)
		}
		
		return nil
	}
	
	// MARK: - Utility Methods
	
	public func hasValue(for key: UserDefaultsKey) -> Bool {
		return queue.sync {
			return userDefaults.object(forKey: key.rawValue) != nil
		}
	}
	
	public func resetToDefaults() {
		queue.sync {
			// Удаляем все существующие ключи
			for key in UserDefaultsKey.allCases {
				userDefaults.removeObject(forKey: key.rawValue)
			}
			
			// Устанавливаем значения по умолчанию
			setupDefaultValues()
			
			// Принудительно синхронизируем
			userDefaults.synchronize()
		}
	}
	
	public func clearAllData() -> Bool {
		return queue.sync {
			// Получаем bundle identifier приложения
			guard let bundleId = Bundle.main.bundleIdentifier else {
				return false
			}
			
			// Удаляем все данные домена приложения
			userDefaults.removePersistentDomain(forName: bundleId)
			
			// Принудительно синхронизируем
			let success = userDefaults.synchronize()
			
			return success
		}
	}
	
	public func synchronize() {
		userDefaults.synchronize()
	}
	
	// MARK: - Private Methods
	
	/// Seeds every ``UserDefaultsKey`` case that declares a default value into `UserDefaults` if no value is stored yet.
	private func setupDefaultValues() {
		for key in UserDefaultsKey.allCases {
			// Устанавливаем значение по умолчанию только если ключ не существует
			if !hasValueDirectly(for: key), let defaultValue = key.defaultValue {
				userDefaults.set(defaultValue, forKey: key.rawValue)
			}
		}
	}
	
	/// Checks whether a value is stored for the key, bypassing the thread-safety queue. Internal use only.
	private func hasValueDirectly(for key: UserDefaultsKey) -> Bool {
		return userDefaults.object(forKey: key.rawValue) != nil
	}
}
