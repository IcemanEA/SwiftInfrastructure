//
//  INotificationManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A manager for push and local notifications — permission, device-token plumbing, and scheduling.
public protocol INotificationManager: Sendable {

	/// Requests the user's permission to deliver notifications.
	///
	/// - Returns: `true` if permission was granted, `false` otherwise.
	func requestPermission() async -> Bool

	/// Returns the current notification-authorization status.
	///
	/// - Returns: The current authorization status (`authorized`, `denied`, `notDetermined`, etc.).
	func getAuthorizationStatus() async -> NotificationAuthorizationStatus

	/// Returns the APNs device token, waiting for it when none has been reported yet.
	///
	/// Returns the most recently reported token at once. Otherwise waits for the next
	/// call to ``notifyTokenReceived(_:)``. Returns `nil` when the timeout elapses first
	/// or when the calling task is cancelled.
	///
	/// - Parameter timeout: The longest time to wait, in seconds.
	/// - Returns: The token, or `nil` on timeout or cancellation.
	func deviceToken(timeout: TimeInterval) async -> String?

	/// Returns a stream of APNs device tokens.
	///
	/// The stream first yields the most recent token known when the subscription takes
	/// effect, if there is one, and then every reported token that differs from the
	/// last one it yielded. Each call returns an independent stream; ending the
	/// iteration stops delivery to it.
	///
	/// - Returns: A stream that never finishes on its own.
	func deviceTokens() -> AsyncStream<String>

	/// Reports a device token received from APNs, typically from
	/// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
	///
	/// - Parameter token: The token string.
	func notifyTokenReceived(_ token: String) async

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
