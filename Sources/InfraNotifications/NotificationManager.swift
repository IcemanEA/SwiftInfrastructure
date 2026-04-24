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

public final class NotificationManager: INotificationManager {

	// MARK: - Private Properties

	private let center: UNUserNotificationCenter
	private let logger: LogManager
	private var tokenCompletions: [(String) -> Void] = []
	private var lastReceivedToken: String?

	// MARK: - Initialization

	public init(
		center: UNUserNotificationCenter = .current(),
		logger: LogManager
	) {
		self.center = center
		self.logger = logger
	}

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

	public func waitForDeviceToken(completion: @escaping (String) -> Void) {
		// Если токен уже был получен, вызываем completion сразу
		if let token = lastReceivedToken {
			completion(token)
		} else {
			// Иначе сохраняем completion для вызова позже
			tokenCompletions.append(completion)
		}
	}

	public func notifyTokenReceived(_ token: String) {
		lastReceivedToken = token

		// Вызываем все ожидающие completions
		for completion in tokenCompletions {
			completion(token)
		}

		// Очищаем массив completions
		tokenCompletions.removeAll()
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
