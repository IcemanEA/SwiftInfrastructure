//
//  NotificationAuthorizationStatus.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import UserNotifications

// MARK: - Custom Authorization Status

/// A library-local mirror of `UNAuthorizationStatus` so consumers don't have to import `UserNotifications`.
public enum NotificationAuthorizationStatus {
	/// The user has not yet been asked for notification permission.
	case notDetermined

	/// The user has explicitly denied notifications for the application.
	case denied

	/// The user has granted full notification rights (sound, banners, badges).
	case authorized

	/// The user has granted only silent notifications (no sound or banners, only in the Notification Center). Available on iOS 12+.
	case provisional

	/// A temporary authorization for App Clips or other short-lived apps. Available on iOS 14+.
	case ephemeral

	/// Bridges from the system `UNAuthorizationStatus`.
	public init(from status: UNAuthorizationStatus) {
		switch status {
		case .notDetermined:
			self = .notDetermined
		case .denied:
			self = .denied
		case .authorized:
			self = .authorized
		case .provisional:
			self = .provisional
		case .ephemeral:
			self = .ephemeral
		@unknown default:
			self = .notDetermined
		}
	}
	
	/// Bridges to the system `UNAuthorizationStatus`.
	public var systemStatus: UNAuthorizationStatus {
		switch self {
		case .notDetermined:
			return .notDetermined
		case .denied:
			return .denied
		case .authorized:
			return .authorized
		case .provisional:
			return .provisional
		case .ephemeral:
			return .ephemeral
		}
	}
	
	/// Whether notifications are permitted in any form (full, provisional, or ephemeral).
	public var isAuthorized: Bool {
		return self == .authorized || self == .provisional || self == .ephemeral
	}
}
