//
//  DeviceTokenTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Foundation
import Testing
import InfraCore
import InfraNotifications
import InfraTestSupport

@Suite("NotificationManager device token")
struct DeviceTokenTests {

	private func makeSut() -> NotificationManager {
		NotificationManager(logger: LogManager(logger: MockLogger(), category: .general))
	}

	private func sleep(_ seconds: Double) async {
		try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
	}

	// MARK: - Waiting

	@Test("A reported token is remembered")
	func tokenIsRemembered() async {
		let sut = makeSut()
		await sut.notifyTokenReceived("t1")

		let start = Date()
		let token = await sut.deviceToken(timeout: 1)

		#expect(token == "t1")
		#expect(Date().timeIntervalSince(start) < 0.5)
	}

	@Test("A token reported while waiting is returned before the timeout")
	func tokenArrivesBeforeTimeout() async {
		let sut = makeSut()

		async let token = sut.deviceToken(timeout: 5)
		await sleep(0.1)
		await sut.notifyTokenReceived("t1")

		#expect(await token == "t1")
	}

	@Test("Waiting returns nil when the timeout elapses")
	func timeoutElapses() async {
		let sut = makeSut()

		let start = Date()
		let token = await sut.deviceToken(timeout: 0.2)
		let elapsed = Date().timeIntervalSince(start)

		#expect(token == nil)
		#expect(elapsed >= 0.15)
		#expect(elapsed < 1)
	}

	@Test("Every concurrent waiter receives the token")
	func severalWaiters() async {
		let sut = makeSut()

		async let first = sut.deviceToken(timeout: 5)
		async let second = sut.deviceToken(timeout: 5)
		async let third = sut.deviceToken(timeout: 5)
		await sleep(0.1)
		await sut.notifyTokenReceived("t1")

		let tokens = await [first, second, third]
		#expect(tokens == ["t1", "t1", "t1"])
	}

	// MARK: - Cancellation

	@Test("A cancelled waiter returns nil promptly and a later token is still accepted")
	func cancelledWaiter() async {
		let sut = makeSut()

		let start = Date()
		let waiting = Task { await sut.deviceToken(timeout: 60) }
		await sleep(0.05)
		waiting.cancel()
		let token = await waiting.value

		#expect(token == nil)
		#expect(Date().timeIntervalSince(start) < 1)

		await sut.notifyTokenReceived("t1")
		#expect(await sut.deviceToken(timeout: 0) == "t1")
	}

	@Test("A task group racing the token against a timer finishes without a token")
	func taskGroupFinishes() async {
		let sut = makeSut()

		let start = Date()
		await withTaskGroup(of: String?.self) { group in
			group.addTask { await sut.deviceToken(timeout: 60) }
			group.addTask {
				try? await Task.sleep(nanoseconds: 100_000_000)
				return nil
			}
			_ = await group.next()
			group.cancelAll()
		}

		#expect(Date().timeIntervalSince(start) < 1)
	}

	// MARK: - Subscribing

	@Test("A subscriber receives the current token and then only changes")
	func currentTokenThenChanges() async {
		let sut = makeSut()
		await sut.notifyTokenReceived("t1")

		var iterator = sut.deviceTokens().makeAsyncIterator()
		let first = await iterator.next()

		await sut.notifyTokenReceived("t1")
		await sut.notifyTokenReceived("t2")
		await sut.notifyTokenReceived("t3")
		let second = await iterator.next()
		let third = await iterator.next()

		#expect([first, second, third] == ["t1", "t2", "t3"])
	}

	@Test("A subscriber that starts before any token receives the first one")
	func subscriberBeforeAnyToken() async {
		let sut = makeSut()

		var iterator = sut.deviceTokens().makeAsyncIterator()
		await sut.notifyTokenReceived("t1")

		#expect(await iterator.next() == "t1")
	}

	@Test("Independent streams each receive the token")
	func independentStreams() async {
		let sut = makeSut()

		var first = sut.deviceTokens().makeAsyncIterator()
		var second = sut.deviceTokens().makeAsyncIterator()
		await sut.notifyTokenReceived("t1")

		#expect(await first.next() == "t1")
		#expect(await second.next() == "t1")
	}

	@Test("A cancelled subscriber stops and a later token is still accepted")
	func cancelledSubscriber() async {
		let sut = makeSut()

		let iterating = Task {
			var received: [String] = []
			for await token in sut.deviceTokens() {
				received.append(token)
			}
			return received
		}
		await sleep(0.05)
		iterating.cancel()
		let received = await iterating.value

		await sut.notifyTokenReceived("t1")

		#expect(received.isEmpty)
		#expect(await sut.deviceToken(timeout: 0) == "t1")
	}
}
