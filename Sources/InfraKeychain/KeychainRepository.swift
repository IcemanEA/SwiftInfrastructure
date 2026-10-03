//
//  KeychainRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

public final class KeychainRepository: IKeychainRepository {

	private let service: String = "secrets"
	private let prefix: String

	private let keychain: IKeychainService

	public init(prefix: String) {
		self.prefix = prefix
		self.keychain = KeychainService()
	}

	/// Creates a repository over the given store. Exists for the package's tests, which inject an in-memory store.
	init(prefix: String, keychain: IKeychainService) {
		self.prefix = prefix
		self.keychain = keychain
	}

	public func getSecret(for type: SecretTokenType) -> SecretToken? {
		let account = prefix + type.rawValue

		if let secret = keychain.getSecret(service: service, account: account) {
			return SecretToken(type: type, rawValue: secret)
		} else {
			return nil
		}
	}

	public func saveSecret(_ token: SecretToken) -> Bool {
		let account = prefix + token.type.rawValue

		let result = keychain.saveSecret(service: service, account: account, secret: token.rawValue)

		if result {
			return true
		} else {
			return updateSecret(token)
		}
	}

	public func deleteSecret(for type: SecretTokenType) -> Bool {
		let account = prefix + type.rawValue

		return keychain.deleteSecret(service: service, account: account)
	}

	public func updateSecret(_ token: SecretToken) -> Bool {
		let account = prefix + token.type.rawValue

		return keychain.updateSecret(service: service, account: account, secret: token.rawValue)
	}

	public func clearAllSecrets() -> Bool {
		return keychain.clearAllSecrets()
	}
}
