//
//  InMemoryKeychainService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.10.2026.
//

@testable import InfraKeychain

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
/// Each test owns its own instance, so no synchronisation is needed.
final class InMemoryKeychainService: IKeychainService {

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

	/// When `true`, add, update and delete fail without changing the store.
	var failsWrites = false

	private(set) var items: [Key: String] = [:]
	private(set) var operations: [Operation] = []

	func getSecret(service: String, account: String) -> String? {
		operations.append(.get(account: account))
		return items[Key(service: service, account: account)]
	}

	func saveSecret(service: String, account: String, secret: String) -> Bool {
		operations.append(.add(account: account))
		let key = Key(service: service, account: account)
		guard !failsWrites, items[key] == nil else { return false }
		items[key] = secret
		return true
	}

	func deleteSecret(service: String, account: String) -> Bool {
		operations.append(.delete(account: account))
		let key = Key(service: service, account: account)
		guard !failsWrites, items[key] != nil else { return false }
		items[key] = nil
		return true
	}

	func updateSecret(service: String, account: String, secret: String) -> Bool {
		operations.append(.update(account: account))
		let key = Key(service: service, account: account)
		guard !failsWrites, items[key] != nil else { return false }
		items[key] = secret
		return true
	}

	func clearAllSecrets() -> Bool {
		operations.append(.clearAll)
		items.removeAll()
		return true
	}
}
