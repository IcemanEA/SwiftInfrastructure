//
//  LockedState.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Foundation

/// A value guarded by a lock, for test doubles of protocols with synchronous requirements.
///
/// ## Overview
///
/// An actor cannot satisfy a synchronous protocol requirement, and `Mutex` needs
/// iOS 18. `LockedState` fills that gap for test code: it stores one value and
/// gives exclusive access to it through ``withLock(_:)``. A test double keeps all
/// of its mutable state in one `LockedState` and is then `Sendable` without an
/// unchecked conformance of its own.
///
/// Do not let a reference to the value escape the closure passed to
/// ``withLock(_:)``; copy what you need and return it. The lock is not
/// reentrant: calling ``withLock(_:)`` on the same instance from inside its own
/// closure, directly or through code it calls, deadlocks.
///
/// ```swift
/// final class RecordingStore: IKeyValueStore, Sendable {
///     private let state = LockedState<[String: String]>([:])
///
///     func set(_ value: String, for key: String) {
///         state.withLock { $0[key] = value }
///     }
///
///     func value(for key: String) -> String? {
///         state.withLock { $0[key] }
///     }
/// }
/// ```
public final class LockedState<Value>: @unchecked Sendable {

	private let lock = NSLock()
	private var value: Value

	/// Creates the container with an initial value.
	///
	/// - Parameter initialValue: The value stored before any access.
	public init(_ initialValue: Value) {
		self.value = initialValue
	}

	/// Runs a closure with exclusive access to the stored value.
	///
	/// - Parameter body: A closure that may read and modify the value in place.
	/// - Returns: The value returned by `body`.
	/// - Throws: Any error thrown by `body`; the lock is released first.
	public func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }
		return try body(&value)
	}
}
