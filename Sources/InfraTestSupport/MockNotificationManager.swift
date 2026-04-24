//
//  MockNotificationManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraNotifications

public final class MockNotificationManager: INotificationManager {
	
	public var requestPermissionCalled = false
	public var requestPermissionResult = true
	
	public var getAuthorizationStatusCalled = false
	public var getAuthorizationStatusResult = NotificationAuthorizationStatus.authorized
	
	public var scheduleNotificationCalled = false
	public var scheduleNotificationResult = true
	
	public var cancelNotificationCalled = false
	public var cancelNotificationId: String?
	
	public var cancelAllNotificationsCalled = false
	
	public var convertTokenToStringCalled = false
	public var convertTokenToStringResult = "mock_token_123"
	
	private var tokenCompletions: [(String) -> Void] = []
	
	public init() {}
	
	public func requestPermission() async -> Bool {
		requestPermissionCalled = true
		return requestPermissionResult
	}
	
	public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
		getAuthorizationStatusCalled = true
		return getAuthorizationStatusResult
	}
	
	public func waitForDeviceToken(completion: @escaping (String) -> Void) {
		tokenCompletions.append(completion)
		// Для тестов можем сразу вызвать completion с моковым токеном
		completion("mock_device_token")
	}
	
	public func notifyTokenReceived(_ token: String) {
		for completion in tokenCompletions {
			completion(token)
		}
		tokenCompletions.removeAll()
	}
	
	public func scheduleNotification(
		id: String,
		title: String,
		body: String,
		timeInterval: TimeInterval,
		userInfo: [AnyHashable : Any]
	) async -> Bool {
		scheduleNotificationCalled = true
		return scheduleNotificationResult
	}
	
	public func cancelNotification(withId id: String) {
		cancelNotificationCalled = true
		cancelNotificationId = id
	}
	
	public func cancelAllNotifications() {
		cancelAllNotificationsCalled = true
	}
	
	public func convertTokenToString(_ token: Data) -> String {
		convertTokenToStringCalled = true
		return convertTokenToStringResult
	}
}
