//
//  KeychainRepositoryTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.10.2026.
//

import Testing
@testable import InfraKeychain

@Suite("KeychainRepository")
struct KeychainRepositoryTests {

	private let store = InMemoryKeychainService()
	private let sut: KeychainRepository

	init() {
		sut = KeychainRepository(prefix: "tests.", keychain: store)
	}

	@Test("Reading a type that was never saved returns nil")
	func readAbsent() {
		#expect(sut.getSecret(for: .jwtToken) == nil)
	}

	@Test("Saved token round-trips its type and value under the prefixed account")
	func saveThenRead() throws {
		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc")))

		let token = try #require(sut.getSecret(for: .jwtToken))
		#expect(token.type == .jwtToken)
		#expect(token.rawValue == "abc")
		#expect(store.items[.init(service: "secrets", account: "tests.jwt_token")] == "abc")
	}

	@Test("Repositories with different prefixes over one store do not see each other's tokens")
	func prefixesIsolate() {
		let other = KeychainRepository(prefix: "other.", keychain: store)

		#expect(sut.saveSecret(SecretToken(type: .profileId, rawValue: "42")))

		#expect(other.getSecret(for: .profileId) == nil)
		#expect(sut.getSecret(for: .profileId)?.rawValue == "42")
	}

	@Test("Saving the same type twice falls back from add to update and keeps the second value")
	func saveTwiceUpdates() {
		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "first")))
		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "second")))

		#expect(sut.getSecret(for: .jwtToken)?.rawValue == "second")
		#expect(store.operations.prefix(3) == [
			.add(account: "tests.jwt_token"),
			.add(account: "tests.jwt_token"),
			.update(account: "tests.jwt_token")
		])
	}

	@Test("A store that rejects writes makes save report failure and stores nothing")
	func failingStore() {
		store.failsWrites = true

		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc")) == false)
		#expect(sut.getSecret(for: .jwtToken) == nil)
	}

	@Test("Deleting an existing token succeeds and removes it")
	func deleteExisting() {
		#expect(sut.saveSecret(SecretToken(type: .devicePassword, rawValue: "pw")))

		#expect(sut.deleteSecret(for: .devicePassword))
		#expect(sut.getSecret(for: .devicePassword) == nil)
	}

	@Test("Updating a token that was never saved reports failure")
	func updateMissing() {
		#expect(sut.updateSecret(SecretToken(type: .jwtToken, rawValue: "abc")) == false)
		#expect(sut.getSecret(for: .jwtToken) == nil)
	}

	@Test("clearAllSecrets returns the store's result and leaves nothing readable")
	func clearAll() {
		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "a")))
		#expect(sut.saveSecret(SecretToken(type: .profileId, rawValue: "b")))

		#expect(sut.clearAllSecrets())
		#expect(sut.getSecret(for: .jwtToken) == nil)
		#expect(sut.getSecret(for: .profileId) == nil)
	}
}
