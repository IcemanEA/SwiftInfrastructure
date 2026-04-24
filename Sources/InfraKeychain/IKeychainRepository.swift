//
//  IKeychainRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

// MARK: - IKeychainRepository

/// A repository for managing secret tokens in secure storage (iOS Keychain).
///
/// ## Overview
///
/// Defines the interface for storing, reading, and deleting secret tokens —
/// for example authentication tokens and push-notification tokens. All
/// operations go through secure storage (iOS Keychain) for confidentiality.
///
/// Capabilities:
/// - Storing tokens encrypted at rest.
/// - Reading tokens with automatic decryption.
/// - Deleting tokens from storage.
/// - Supporting multiple token kinds via ``SecretTokenType``.
///
/// ## Secret masking
///
/// Tokens are automatically masked in log output because ``SecretToken``
/// conforms to ``MaskStringConvertible``, preventing accidental leaks during
/// debugging.
///
/// ```swift
/// let repository: IKeychainRepository = KeychainRepository(prefix: "com.example.myapp.")
///
/// // Save a push-notification token.
/// let notificationToken = SecretToken(type: .pushNotificationToken, rawValue: "fcm_token_123")
/// let saved = repository.saveSecret(notificationToken)
///
/// // Read it back.
/// if let token = repository.getSecret(for: .pushNotificationToken) {
///     print("Token: \(token)") // Prints "Token: ***********"
/// }
///
/// // Delete it.
/// let deleted = repository.deleteSecret(for: .pushNotificationToken)
/// ```
///
/// ## Error handling
///
/// Write and delete methods return `Bool` so the caller can detect failures:
///
/// ```swift
/// let success = repository.saveSecret(token)
/// if !success {
///     print("Failed to save authorization token")
/// }
/// ```
///
/// ## Thread safety
///
/// Implementations must be thread-safe — tokens may be updated from any
/// thread (for example when an FCM token refresh arrives on a background
/// queue).
public protocol IKeychainRepository {

	/// Reads a secret token from secure storage.
	///
	/// Safely retrieves the token from encrypted storage and returns it as a
	/// ``SecretToken`` whose string representation is automatically masked in
	/// log output.
	///
	/// - Parameter type: The kind of token to read.
	/// - Returns: The stored token, or `nil` if not found.
	///
	/// Returns `nil` when:
	/// - The token has not been saved.
	/// - The token was deleted.
	/// - Keychain access failed.
	/// - The token is corrupted or cannot be decrypted.
	///
	/// ```swift
	/// if let authToken = repository.getSecret(for: .jwtToken) {
	///     apiClient.setAuthToken(authToken.rawValue)
	/// } else {
	///     showLoginScreen()
	/// }
	/// ```
	func getSecret(for type: SecretTokenType) -> SecretToken?

	/// Stores a secret token in secure storage, creating or replacing the entry for its type.
	///
	/// - Parameter token: The token to save.
	/// - Returns: `true` if the token was stored, `false` on error.
	///
	/// Returns `false` when:
	/// - Keychain access failed.
	/// - Storage is full.
	/// - Encryption failed.
	///
	/// ```swift
	/// let fcmToken = SecretToken(type: .pushNotificationToken, rawValue: fcmTokenString)
	/// if repository.saveSecret(fcmToken) {
	///     sendTokenToServer(fcmTokenString)
	/// } else {
	///     // retry or surface an error
	/// }
	/// ```
	func saveSecret(_ token: SecretToken) -> Bool

	/// Deletes a secret token from secure storage.
	///
	/// The deletion is irreversible.
	///
	/// - Parameter type: The kind of token to delete.
	/// - Returns: `true` if the token was deleted (or did not exist), `false` on error.
	///
	/// Typical use cases:
	/// - User sign-out.
	/// - Disabling push notifications.
	/// - Account switch.
	/// - Application reset.
	///
	/// ```swift
	/// func logout() {
	///     let authDeleted = repository.deleteSecret(for: .jwtToken)
	///     let notificationDeleted = repository.deleteSecret(for: .pushNotificationToken)
	///     if authDeleted && notificationDeleted {
	///         navigateToLoginScreen()
	///     }
	/// }
	/// ```
	func deleteSecret(for type: SecretTokenType) -> Bool

	/// Removes every secret from the Keychain, including auth and notification tokens.
	///
	/// > Warning: This removes all data stored by this repository. Use only for
	/// > a full application reset.
	///
	/// - Returns: `true` on success, `false` on error.
	func clearAllSecrets() -> Bool
}
