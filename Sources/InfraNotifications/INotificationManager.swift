//
//  INotificationManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A manager for push and local notifications — permission, device-token plumbing, and scheduling.
public protocol INotificationManager {

	/// Requests the user's permission to deliver notifications.
	///
	/// - Returns: `true` if permission was granted, `false` otherwise.
	func requestPermission() async -> Bool

	/// Returns the current notification-authorization status.
	///
	/// - Returns: The current authorization status (`authorized`, `denied`, `notDetermined`, etc.).
	func getAuthorizationStatus() async -> NotificationAuthorizationStatus

	/// Invokes the closure when an APNS device token becomes available.
	///
	/// - Parameter completion: A closure called with the token string once it has been registered.
	func waitForDeviceToken(completion: @escaping (String) -> Void)

	/// Notifies the manager that a device token has been received from APNS.
	///
	/// - Parameter token: The token string.
	func notifyTokenReceived(_ token: String)

	/// Schedules a local notification to fire after a delay.
	///
	/// - Parameters:
	///   - id: A unique identifier for this notification.
	///   - title: The notification title.
	///   - body: The notification body text.
	///   - timeInterval: The delay in seconds before the notification fires.
	///   - userInfo: Additional payload to deliver with the notification.
	/// - Returns: `true` if the notification was successfully scheduled, `false` otherwise.
	func scheduleNotification(
		id: String,
		title: String,
		body: String,
		timeInterval: TimeInterval,
		userInfo: [AnyHashable: Any]
	) async -> Bool

	/// Cancels a specific notification by identifier.
	///
	/// - Parameter id: The identifier of the notification to cancel.
	func cancelNotification(withId id: String)

	/// Cancels every pending and delivered notification.
	func cancelAllNotifications()

	/// Converts a raw APNS device-token `Data` value into its hex-string representation.
	///
	/// - Parameter token: The device-token data as delivered by APNS.
	/// - Returns: The token encoded as a hex string.
	func convertTokenToString(_ token: Data) -> String
}
