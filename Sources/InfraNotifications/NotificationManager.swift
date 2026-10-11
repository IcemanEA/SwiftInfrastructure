//
//  NotificationManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import SwiftUI
import UIKit
import UserNotifications
import InfraCore

public final class NotificationManager: INotificationManager, Sendable {

	// MARK: - Private Properties

	private let logger: LogManager
	private let tokenBroker = DeviceTokenBroker()

	// MARK: - Initialization

	/// Creates the manager over the app's shared notification center.
	///
	/// - Parameter logger: The sink for the manager's log messages.
	public init(logger: LogManager) {
		self.logger = logger
	}

	/// The app's shared notification center, looked up on each use.
	///
	/// Not stored: `UNUserNotificationCenter` is not `Sendable`, so a stored instance
	/// would make this manager non-`Sendable`.
	private var center: UNUserNotificationCenter { .current() }

	// MARK: - Public Methods

	public func requestPermission() async -> Bool {
		do {
			let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

			if granted {
				logger.info("Notification permission granted")
				await requestDeviceToken()
			} else {
				logger.warning("Notification permission denied")
			}

			return granted
		} catch {
			logger.error("Notification permission error: \(error)")
			return false
		}
	}

	public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
		let settings = await center.notificationSettings()
		return NotificationAuthorizationStatus(from: settings.authorizationStatus)
	}

	public func deviceToken(timeout: TimeInterval) async -> String? {
		await tokenBroker.token(timeout: timeout)
	}

	public func deviceTokens() -> AsyncStream<String> {
		tokenBroker.tokens()
	}

	public func notifyTokenReceived(_ token: String) async {
		await tokenBroker.notify(token)
	}

	public func scheduleNotification(
		id: String = UUID().uuidString,
		title: String,
		body: String,
		timeInterval: TimeInterval = 1,
		userInfo: [AnyHashable: Any] = [:]
	) async -> Bool {
		let status = await getAuthorizationStatus()
		guard status.isAuthorized else {
			logger.warning("Notifications not authorized, status: \(status)")
			return false
		}

		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = .default
		content.userInfo = userInfo

		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
		let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

		do {
			try await center.add(request)
			logger.info("Notification scheduled: \(title)")
			return true
		} catch {
			logger.error("Failed to schedule notification: \(error)")
			return false
		}
	}

	public func cancelNotification(withId id: String) {
		center.removePendingNotificationRequests(withIdentifiers: [id])
		center.removeDeliveredNotifications(withIdentifiers: [id])
		logger.info("Notification cancelled: \(id)")
	}

	public func cancelAllNotifications() {
		center.removeAllPendingNotificationRequests()
		center.removeAllDeliveredNotifications()
		logger.info("All notifications cancelled")
	}

	public func convertTokenToString(_ token: Data) -> String {
		let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
		logger.info("Device token saved: \(tokenString)")
		return tokenString
	}

	// MARK: - Private Methods

	/// Registers the application for remote notifications so the system will deliver a device token.
	private func requestDeviceToken() async {
		await MainActor.run {
			UIApplication.shared.registerForRemoteNotifications()
			logger.info("Requested device token from system")
		}
	}
}
