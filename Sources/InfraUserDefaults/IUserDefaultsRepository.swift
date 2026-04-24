//
//  IUserDefaultsRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 24.06.2025.
//

import Foundation

/// A typed, enum-keyed facade over `UserDefaults` for application settings.
///
/// ## Overview
///
/// Provides a safe, testable, enum-keyed API for reading and writing
/// application settings. Using a centralized repository over `UserDefaults`
/// removes the class of bugs caused by hand-written string keys, keeps data
/// access consistent, and makes testing straightforward.
///
/// Capabilities:
/// - Typed access through ``UserDefaultsKey`` cases.
/// - Automatic default-value fallback.
/// - Safe type casts.
/// - Centralized settings management.
/// - Easy to mock for tests via ``InfraTestSupport``.
///
/// ## Supported value types
///
/// - `String` — text values (themes, languages, versions).
/// - `Bool` — flags (onboarding completion, feature toggles).
/// - `Int` — counters and version numbers.
/// - `Double` — timestamps and metrics.
/// - `Any` — arbitrary values compatible with `UserDefaults`.
///
/// ```swift
/// let repository: IUserDefaultsRepository = UserDefaultsRepository()
///
/// // Onboarding check.
/// let needsOnboarding = !(repository.getBool(for: .onboardingCompleted) ?? false)
/// if needsOnboarding { showOnboardingScreen() }
///
/// // Sync-time bookkeeping.
/// repository.setValue(Date().timeIntervalSince1970, for: .lastJwtSyncTime)
/// ```
///
/// ## Thread safety
///
/// Implementations must be thread-safe — `UserDefaults` can be accessed
/// concurrently from multiple threads.
public protocol IUserDefaultsRepository {

	// MARK: - Generic Methods

	/// Reads a value of any type for the given key, or the key's default if no value is stored.
	///
	/// - Parameter key: The key to read.
	/// - Returns: The stored value, or the key's default if no value is set.
	///
	/// ```swift
	/// let syncTime = repository.getValue(for: .lastJwtSyncTime) // returns 0.0 if not set
	/// ```
	func getValue(for key: UserDefaultsKey) -> Any?

	/// Stores a value of any `UserDefaults`-compatible type for the given key.
	///
	/// - Parameters:
	///   - value: The value to store. Must be a type compatible with `UserDefaults`.
	///   - key: The key to store under.
	///
	/// Supported types: `NSString`, `NSNumber`, `NSDate`, `NSData`, `String`,
	/// `Bool`, `Int`, `Float`, `Double`, and arrays or dictionaries of these.
	///
	/// ```swift
	/// repository.setValue(Date().timeIntervalSince1970, for: .lastJwtSyncTime)
	/// ```
	func setValue(_ value: Any?, for key: UserDefaultsKey)

	/// Removes the value stored for the given key.
	///
	/// After removal, reads return the key's default value.
	///
	/// - Parameter key: The key whose value to remove.
	///
	/// Typical use cases:
	/// - Resetting a setting to its default.
	/// - Clearing state on sign-out.
	/// - Invalidating cached timings.
	func removeValue(for key: UserDefaultsKey)

	// MARK: - Typed Methods

	/// Reads a `String` value for the given key.
	///
	/// - Parameter key: The key to read.
	/// - Returns: The stored string, or `nil` if no value is set or if the stored value cannot be cast to `String`.
	func getString(for key: UserDefaultsKey) -> String?

	/// Reads a `Bool` value for the given key.
	///
	/// - Parameter key: The key to read.
	/// - Returns: The stored flag, or `nil` if no value is set or if the stored value cannot be cast to `Bool`.
	func getBool(for key: UserDefaultsKey) -> Bool?

	/// Reads an `Int` value for the given key.
	///
	/// - Parameter key: The key to read.
	/// - Returns: The stored integer, or `nil` if no value is set or if the stored value cannot be cast to `Int`.
	func getInt(for key: UserDefaultsKey) -> Int?

	/// Reads a `Double` value for the given key.
	///
	/// - Parameter key: The key to read.
	/// - Returns: The stored double, or `nil` if no value is set or if the stored value cannot be cast to `Double`.
	func getDouble(for key: UserDefaultsKey) -> Double?

	// MARK: - Utility Methods

	/// Returns whether any value is stored for the given key (independent of its default).
	///
	/// - Parameter key: The key to check.
	/// - Returns: `true` if a value has been stored for the key, `false` otherwise.
	func hasValue(for key: UserDefaultsKey) -> Bool

	/// Resets every managed key back to its default value.
	///
	/// > Warning: Irreversible — clears every stored setting. Intended for
	/// > application-reset flows or debugging.
	func resetToDefaults()

	/// Removes all settings this repository stores in `UserDefaults`, including user preferences, caches, and bookkeeping values.
	///
	/// > Warning: Irreversible. Use only for a full application reset during
	/// > debugging.
	///
	/// - Returns: `true` on success, `false` on error.
	func clearAllData() -> Bool

	/// Forces the underlying `UserDefaults` to flush pending changes to disk.
	///
	/// `UserDefaults` usually syncs automatically, but in critical moments —
	/// for example before application termination — an explicit `synchronize`
	/// guarantees persistence.
	///
	/// Typical use cases:
	/// - Before application termination.
	/// - After storing critical data that must survive an immediate crash.
	/// - In tests that need to observe a write.
	func synchronize()
}
