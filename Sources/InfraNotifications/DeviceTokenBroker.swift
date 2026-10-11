//
//  DeviceTokenBroker.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Foundation

/// Holds the most recent APNs device token and hands it to waiters and subscribers.
///
/// Every waiter is resolved exactly once, by whichever comes first: a token, its
/// timeout or the cancellation of its task. Subscribers receive the latest token
/// when their subscription takes effect and then every token that differs from
/// the last one they received.
actor DeviceTokenBroker {

	private struct Waiter {
		let continuation: CheckedContinuation<String?, Never>
		let timeout: Task<Void, Never>
	}

	private struct Subscriber {
		let continuation: AsyncStream<String>.Continuation
		var lastYielded: String?
	}

	private var lastToken: String?
	private var waiters: [UUID: Waiter] = [:]
	private var subscribers: [UUID: Subscriber] = [:]

	// MARK: - Reporting

	/// Stores the token and delivers it to every waiter and subscriber.
	func notify(_ token: String) {
		lastToken = token

		let pending = waiters
		waiters.removeAll()
		for waiter in pending.values {
			waiter.timeout.cancel()
			waiter.continuation.resume(returning: token)
		}

		for (id, var subscriber) in subscribers where subscriber.lastYielded != token {
			if case .terminated = subscriber.continuation.yield(token) {
				subscribers[id] = nil
				continue
			}
			subscriber.lastYielded = token
			subscribers[id] = subscriber
		}
	}

	// MARK: - Waiting

	/// Returns the stored token, or waits for the next one until the timeout elapses or the task is cancelled.
	func token(timeout: TimeInterval) async -> String? {
		if let lastToken {
			return lastToken
		}

		let id = UUID()
		return await withTaskCancellationHandler {
			await withCheckedContinuation { continuation in
				let timeoutTask = Task { [weak self] in
					try? await Task.sleep(nanoseconds: Self.nanoseconds(from: timeout))
					await self?.resolve(id, with: nil)
				}
				waiters[id] = Waiter(continuation: continuation, timeout: timeoutTask)

				// Отмена могла прийти до регистрации ожидающего.
				if Task.isCancelled {
					resolve(id, with: nil)
				}
			}
		} onCancel: {
			Task { [weak self] in
				await self?.resolve(id, with: nil)
			}
		}
	}

	/// Converts a timeout in seconds to nanoseconds, treating NaN and negative values as zero
	/// and clamping values too large for `UInt64` (including infinity) to the maximum.
	private static func nanoseconds(from seconds: TimeInterval) -> UInt64 {
		guard !seconds.isNaN, seconds > 0 else { return 0 }
		let nanoseconds = seconds * 1_000_000_000
		guard nanoseconds < Double(UInt64.max) else { return UInt64.max }
		return UInt64(nanoseconds)
	}

	private func resolve(_ id: UUID, with token: String?) {
		guard let waiter = waiters.removeValue(forKey: id) else { return }
		waiter.timeout.cancel()
		waiter.continuation.resume(returning: token)
	}

	// MARK: - Subscribing

	/// Returns a stream of the latest token and every later change.
	nonisolated func tokens() -> AsyncStream<String> {
		let (stream, continuation) = AsyncStream.makeStream(of: String.self)
		let id = UUID()

		continuation.onTermination = { [weak self] _ in
			Task {
				await self?.removeSubscriber(id)
			}
		}
		Task {
			await self.addSubscriber(id, continuation: continuation)
		}

		return stream
	}

	private func addSubscriber(_ id: UUID, continuation: AsyncStream<String>.Continuation) {
		var subscriber = Subscriber(continuation: continuation, lastYielded: nil)

		if let lastToken {
			// Поток мог завершиться до регистрации — тогда хранить его незачем.
			if case .terminated = continuation.yield(lastToken) {
				return
			}
			subscriber.lastYielded = lastToken
		}

		subscribers[id] = subscriber
	}

	private func removeSubscriber(_ id: UUID) {
		subscribers[id] = nil
	}
}
