//
//  SecretTokenType.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 23.06.2025.
//

import Foundation

/// The kind of secret stored in secure storage. Each value is a stable string used as the Keychain account suffix.
public enum SecretTokenType: String, CaseIterable {
	/// A JWT used for API authentication.
	case jwtToken = "jwt_token"

	/// The device-credentials username.
	case deviceUsername = "device_username"

	/// The device-credentials password.
	case devicePassword = "device_password"

	/// A user profile identifier retrieved from the server.
	case profileId = "profile_id"

	/// A push-notification token (APNS / FCM).
	case pushNotificationToken = "push_notification_token"

	/// A human-readable label for debugging and logs.
	var description: String {
		switch self {
		case .jwtToken:
			"JWT Authentication Token"
		case .deviceUsername:
			"Device Credentials: username"
		case .devicePassword:
			"Device Credentials: password"
		case .profileId:
			"Profile UUID from server"
		case .pushNotificationToken:
			"Push Notification Token"
		}
	}

	/// Whether losing or leaking this token has security-critical consequences.
	var isCritical: Bool {
		switch self {
		case .jwtToken, .deviceUsername, .devicePassword:
			return true
		case .profileId, .pushNotificationToken:
			return false
		}
	}
}
