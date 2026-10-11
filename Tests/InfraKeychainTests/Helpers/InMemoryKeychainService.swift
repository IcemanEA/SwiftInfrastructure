//
//  InMemoryKeychainService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.10.2026.
//

@testable import InfraKeychain
import InfraTestSupport

/// An in-memory stand-in for the Keychain, injected into `KeychainRepository` so tests never call `SecItem*`.
///
/// It mirrors only the outcomes the repository relies on:
///
/// | Call              | Item exists                     | Item missing                 |
/// |-------------------|---------------------------------|------------------------------|
/// | `saveSecret`      | `false` (`errSecDuplicateItem`) | stores, `true`               |
/// | `updateSecret`    | replaces, `true`                | `false` (`errSecItemNotFound`) |
/// | `deleteSecret`    | removes, `true`                 | `false` (`errSecItemNotFound`) |
/// | `getSecret`       | the value                       | `nil`                        |
/// | `clearAllSecrets` | removes everything, `true`      | `true`                       |
///
/// State lives in a ``LockedState`` so the store is `Sendable`, as `IKeychainService` requires.
final class InMemoryKeychainService: IKeychainService, Sendable {

	struct Key: Hashable {
		let service: String
		let account: String
	}

	enum Operation: Equatable {
		case get(account: String)
		case add(account: String)
		case update(account: String)
		case delete(account: String)
		case clearAll
	}

	private struct State {
		var failsWrites = false
		var items: [Key: String] = [:]
		var operations: [Operation] = []
	}

	private let state = LockedState(State())

	/// When `true`, add, update and delete fail without changing the store.
	var failsWrites: Bool {
		get { state.withLock { $0.failsWrites } }
		set { state.withLock { $0.failsWrites = newValue } }
	}

	var items: [Key: String] { state.withLock { $0.items } }
	var operations: [Operation] { state.withLock { $0.operations } }

	func getSecret(service: String, account: String) -> String? {
		state.withLock { state in
			state.operations.append(.get(account: account))
			return state.items[Key(service: service, account: account)]
		}
	}

	func saveSecret(service: String, account: String, secret: String) -> Bool {
		state.withLock { state in
			state.operations.append(.add(account: account))
			let key = Key(service: service, account: account)
			guard !state.failsWrites, state.items[key] == nil else { return false }
			state.items[key] = secret
			return true
		}
	}

	func deleteSecret(service: String, account: String) -> Bool {
		state.withLock { state in
			state.operations.append(.delete(account: account))
			let key = Key(service: service, account: account)
			guard !state.failsWrites, state.items[key] != nil else { return false }
			state.items[key] = nil
			return true
		}
	}

	func updateSecret(service: String, account: String, secret: String) -> Bool {
		state.withLock { state in
			state.operations.append(.update(account: account))
			let key = Key(service: service, account: account)
			guard !state.failsWrites, state.items[key] != nil else { return false }
			state.items[key] = secret
			return true
		}
	}

	func clearAllSecrets() -> Bool {
		state.withLock { state in
			state.operations.append(.clearAll)
			state.items.removeAll()
			return true
		}
	}
}
