//
//  IKeychainService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.10.2026.
//

// MARK: - IKeychainService

/// The low-level Keychain operations that ``KeychainRepository`` is built on.
///
/// ## Overview
///
/// A package-internal seam: ``KeychainService`` is the production
/// implementation over `SecItem*`, and the package's tests substitute an
/// in-memory store so repository behaviour can be verified without touching
/// the system Keychain.
protocol IKeychainService {

	/// Returns the secret stored for `service` and `account`, or `nil` if there is none.
	func getSecret(service: String, account: String) -> String?

	/// Adds a new item. Returns `false` if an item for `service` and `account` already exists.
	func saveSecret(service: String, account: String, secret: String) -> Bool

	/// Deletes the item for `service` and `account`. Returns `false` if there is none.
	func deleteSecret(service: String, account: String) -> Bool

	/// Replaces the secret of an existing item. Returns `false` if there is none.
	func updateSecret(service: String, account: String, secret: String) -> Bool

	/// Removes every item the implementation manages.
	func clearAllSecrets() -> Bool
}
