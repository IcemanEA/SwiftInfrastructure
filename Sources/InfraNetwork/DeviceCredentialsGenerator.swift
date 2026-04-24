//
//  DeviceCredentialsGenerator.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 23.06.2025.
//

import Foundation
import CryptoKit

/// A deterministic generator of per-device credentials (username + password).
///
/// ## Overview
///
/// Produces a stable `(username, password)` pair for device-bound authentication
/// using a caller-supplied salt. The derivation is platform-neutral: iOS,
/// Android, and server-side Swift compute the same password for the same
/// username when configured with the same `osType`, `passwordSalt`, and
/// `usernamePrefix`.
///
/// ```swift
/// let generator = DeviceCredentialsGenerator(
///     osType: "ios",
///     passwordSalt: "my-app-specific-salt-v1",
///     usernamePrefix: "dev_"
/// )
/// let (username, password) = generator.generateCredentials()
/// ```
///
/// > Important: The salt is effectively a public constant in a public
/// > repository — rotate it only with a coordinated migration.
public struct DeviceCredentialsGenerator {

	/// The operating-system tag used in the password-derivation input.
	public let osType: String

	/// The salt mixed into the password hash. Must match on every platform that verifies credentials.
	public let passwordSalt: String

	/// The prefix applied to generated usernames so they can be distinguished from other identifiers.
	public let usernamePrefix: String

	public init(osType: String, passwordSalt: String, usernamePrefix: String) {
		self.osType = osType
		self.passwordSalt = passwordSalt
		self.usernamePrefix = usernamePrefix
	}

	/// Generates a fresh `(username, password)` pair. The username is randomized via UUID; the password is derived from it via SHA-256.
	///
	/// - Returns: A tuple containing the generated username and the matching password.
	public func generateCredentials() -> (username: String, password: String) {
		let username = generateUsername()
		let password = generatePassword(username: username)

		return (username: username, password: password)
	}

	/// Derives the password for an existing username using the instance's `osType` and `passwordSalt`.
	///
	/// - Parameter username: The device-bound username to derive a password for.
	/// - Returns: A 20-character password deterministically derived from `username`, `osType`, and `passwordSalt`.
	public func generatePassword(username: String) -> String {
		// Создаем строку для хеширования
		let baseString = [
			username.lowercased(),
			osType.lowercased(),
			passwordSalt
		].joined(separator: "|")

		// Генерируем SHA256 хеш
		let inputData = Data(baseString.utf8)
		let hashed = SHA256.hash(data: inputData)
		let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()

		// Берем части хеша для создания пароля
		let part1 = String(hashString.prefix(8))           // первые 8 символов
		let part2 = String(hashString.suffix(8))           // последние 8 символов
		let middle = String(hashString.dropFirst(16).prefix(4)) // 4 символа из середины

		// Формируем финальный пароль: 8+4+8 = 20 символов
		return "\(part1)\(middle)\(part2)"
	}

	/// Generates a fresh username from a UUID, prefixed with `usernamePrefix` and a one-character OS tag.
	///
	/// - Returns: A username of the form `"<usernamePrefix><o><16 hex chars>"`, where `<o>` is the first letter of `osType`.
	private func generateUsername() -> String {
		// Генерируем новый UUID и убираем дефисы
		let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
		let truncatedId = String(uuid.prefix(16))

		// Добавляем короткий префикс OS
		let osPrefix = osType.prefix(1).lowercased()

		return "\(usernamePrefix)\(osPrefix)\(truncatedId)"
	}

	/// Checks that a username has the shape this generator would produce.
	///
	/// - Parameter username: The username to validate.
	/// - Returns: `true` if the username starts with `usernamePrefix` and has the expected length.
	public func isValidDeviceUsername(_ username: String) -> Bool {
		return username.hasPrefix(usernamePrefix) &&
			   username.count == (usernamePrefix.count + 1 + 16) // prefix + os + 16 chars
	}

	/// Validates a `(username, password)` pair by recomputing the password and comparing.
	///
	/// - Parameters:
	///   - username: The username to validate.
	///   - password: The password expected to match `username`.
	/// - Returns: `true` if the username is in this generator's format and the password matches what it would derive for that username.
	public func validateCredentials(
		username: String,
		password: String
	) -> Bool {
		guard isValidDeviceUsername(username) else { return false }

		let expectedPassword = generatePassword(username: username)
		return password == expectedPassword
	}
}
