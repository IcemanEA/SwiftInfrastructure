//
//  MockNotificationManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraNotifications

/// A configurable ``INotificationManager`` for tests.
///
/// ## Overview
///
/// Returns the configured results, records which methods were called, and hands
/// out a device token without waiting: ``deviceToken(timeout:)`` returns the most
/// recently reported token, or ``deviceTokenResult`` when none was reported.
/// ``deviceTokens()`` yields that token first and then every token passed to
/// ``notifyTokenReceived(_:)``. State lives in a ``LockedState``, so the mock is
/// safe to share across tasks and actors.
///
/// ```swift
/// let manager = MockNotificationManager()
/// manager.requestPermissionResult = false
/// #expect(await manager.requestPermission() == false)
/// #expect(await manager.deviceToken(timeout: 1) == "mock_device_token")
/// ```
public final class MockNotificationManager: INotificationManager, Sendable {

	private struct State {
		var requestPermissionCalled = false
		var requestPermissionResult = true
		var getAuthorizationStatusCalled = false
		var getAuthorizationStatusResult = NotificationAuthorizationStatus.authorized
		var scheduleNotificationCalled = false
		var scheduleNotificationResult = true
		var cancelNotificationCalled = false
		var cancelNotificationId: String?
		var cancelAllNotificationsCalled = false
		var convertTokenToStringCalled = false
		var convertTokenToStringResult = "mock_token_123"
		var deviceTokenResult: String? = "mock_device_token"
		var reportedTokens: [String] = []
		var subscribers: [UUID: AsyncStream<String>.Continuation] = [:]
	}

	private let state = LockedState(State())

	public init() {}

	// MARK: - Configuration and recorded calls

	/// Whether ``requestPermission()`` was called.
	public var requestPermissionCalled: Bool {
		get { state.withLock { $0.requestPermissionCalled } }
		set { state.withLock { $0.requestPermissionCalled = newValue } }
	}

	/// The value ``requestPermission()`` returns.
	public var requestPermissionResult: Bool {
		get { state.withLock { $0.requestPermissionResult } }
		set { state.withLock { $0.requestPermissionResult = newValue } }
	}

	/// Whether ``getAuthorizationStatus()`` was called.
	public var getAuthorizationStatusCalled: Bool {
		get { state.withLock { $0.getAuthorizationStatusCalled } }
		set { state.withLock { $0.getAuthorizationStatusCalled = newValue } }
	}

	/// The value ``getAuthorizationStatus()`` returns.
	public var getAuthorizationStatusResult: NotificationAuthorizationStatus {
		get { state.withLock { $0.getAuthorizationStatusResult } }
		set { state.withLock { $0.getAuthorizationStatusResult = newValue } }
	}

	/// Whether ``scheduleNotification(id:title:body:timeInterval:userInfo:)`` was called.
	public var scheduleNotificationCalled: Bool {
		get { state.withLock { $0.scheduleNotificationCalled } }
		set { state.withLock { $0.scheduleNotificationCalled = newValue } }
	}

	/// The value ``scheduleNotification(id:title:body:timeInterval:userInfo:)`` returns.
	public var scheduleNotificationResult: Bool {
		get { state.withLock { $0.scheduleNotificationResult } }
		set { state.withLock { $0.scheduleNotificationResult = newValue } }
	}

	/// Whether ``cancelNotification(withId:)`` was called.
	public var cancelNotificationCalled: Bool {
		get { state.withLock { $0.cancelNotificationCalled } }
		set { state.withLock { $0.cancelNotificationCalled = newValue } }
	}

	/// The identifier passed to the last ``cancelNotification(withId:)`` call.
	public var cancelNotificationId: String? {
		get { state.withLock { $0.cancelNotificationId } }
		set { state.withLock { $0.cancelNotificationId = newValue } }
	}

	/// Whether ``cancelAllNotifications()`` was called.
	public var cancelAllNotificationsCalled: Bool {
		get { state.withLock { $0.cancelAllNotificationsCalled } }
		set { state.withLock { $0.cancelAllNotificationsCalled = newValue } }
	}

	/// Whether ``convertTokenToString(_:)`` was called.
	public var convertTokenToStringCalled: Bool {
		get { state.withLock { $0.convertTokenToStringCalled } }
		set { state.withLock { $0.convertTokenToStringCalled = newValue } }
	}

	/// The value ``convertTokenToString(_:)`` returns.
	public var convertTokenToStringResult: String {
		get { state.withLock { $0.convertTokenToStringResult } }
		set { state.withLock { $0.convertTokenToStringResult = newValue } }
	}

	/// The token handed out before any token is reported; `nil` simulates a device that never receives one.
	public var deviceTokenResult: String? {
		get { state.withLock { $0.deviceTokenResult } }
		set { state.withLock { $0.deviceTokenResult = newValue } }
	}

	/// Every token passed to ``notifyTokenReceived(_:)``, in call order.
	public var reportedTokens: [String] {
		state.withLock { $0.reportedTokens }
	}

	// MARK: - INotificationManager

	public func requestPermission() async -> Bool {
		state.withLock { state in
			state.requestPermissionCalled = true
			return state.requestPermissionResult
		}
	}

	public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
		state.withLock { state in
			state.getAuthorizationStatusCalled = true
			return state.getAuthorizationStatusResult
		}
	}

	public func deviceToken(timeout: TimeInterval) async -> String? {
		state.withLock { $0.reportedTokens.last ?? $0.deviceTokenResult }
	}

	public func deviceTokens() -> AsyncStream<String> {
		let (stream, continuation) = AsyncStream.makeStream(of: String.self)
		let id = UUID()

		continuation.onTermination = { [state] _ in
			state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
		}
		state.withLock { state in
			if let token = state.reportedTokens.last ?? state.deviceTokenResult {
				continuation.yield(token)
			}
			state.subscribers[id] = continuation
		}

		return stream
	}

	public func notifyTokenReceived(_ token: String) async {
		let subscribers = state.withLock { state in
			state.reportedTokens.append(token)
			return Array(state.subscribers.values)
		}
		for subscriber in subscribers {
			subscriber.yield(token)
		}
	}

	public func scheduleNotification(
		id: String,
		title: String,
		body: String,
		timeInterval: TimeInterval,
		userInfo: [AnyHashable: Any]
	) async -> Bool {
		state.withLock { state in
			state.scheduleNotificationCalled = true
			return state.scheduleNotificationResult
		}
	}

	public func cancelNotification(withId id: String) {
		state.withLock { state in
			state.cancelNotificationCalled = true
			state.cancelNotificationId = id
		}
	}

	public func cancelAllNotifications() {
		state.withLock { $0.cancelAllNotificationsCalled = true }
	}

	public func convertTokenToString(_ token: Data) -> String {
		state.withLock { state in
			state.convertTokenToStringCalled = true
			return state.convertTokenToStringResult
		}
	}
}
