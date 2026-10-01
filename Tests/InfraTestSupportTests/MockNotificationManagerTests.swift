//
//  MockNotificationManagerTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraNotifications
import InfraTestSupport

@Suite("MockNotificationManager")
struct MockNotificationManagerTests {

	private let sut = MockNotificationManager()

	@Test("requestPermission returns the configured result and records the call")
	func requestPermission() async {
		sut.requestPermissionResult = false

		let granted = await sut.requestPermission()

		#expect(granted == false)
		#expect(sut.requestPermissionCalled)
	}

	@Test("getAuthorizationStatus returns the configured status")
	func authorizationStatus() async {
		sut.getAuthorizationStatusResult = .denied

		let status = await sut.getAuthorizationStatus()

		#expect(status == .denied)
		#expect(sut.getAuthorizationStatusCalled)
	}

	@Test("scheduleNotification returns the configured result")
	func scheduleNotification() async {
		sut.scheduleNotificationResult = false

		let scheduled = await sut.scheduleNotification(id: "1", title: "t", body: "b", timeInterval: 1, userInfo: [:])

		#expect(scheduled == false)
		#expect(sut.scheduleNotificationCalled)
	}

	@Test("waitForDeviceToken delivers a mock token immediately")
	func immediateTokenDelivery() {
		var received: String?

		sut.waitForDeviceToken { received = $0 }

		#expect(received == "mock_device_token")
	}

	@Test("cancelNotification records the identifier")
	func cancelNotification() {
		sut.cancelNotification(withId: "abc")

		#expect(sut.cancelNotificationCalled)
		#expect(sut.cancelNotificationId == "abc")
	}

	@Test("cancelAllNotifications records the call")
	func cancelAll() {
		sut.cancelAllNotifications()

		#expect(sut.cancelAllNotificationsCalled)
	}

	@Test("convertTokenToString returns the configured string")
	func convertToken() {
		sut.convertTokenToStringResult = "configured"

		#expect(sut.convertTokenToString(Data([0xAB])) == "configured")
		#expect(sut.convertTokenToStringCalled)
	}
}
