//
//  MockKeychainRepositoryTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraCore
import InfraKeychain
import InfraTestSupport

@Suite("MockKeychainRepository")
struct MockKeychainRepositoryTests {

	private let sut = MockKeychainRepository()

	@Test("Saved token is readable by type and counted")
	func saveThenRead() {
		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc")))

		#expect(sut.getSecret(for: .jwtToken)?.rawValue == "abc")
		#expect(sut.callCounts.save == 1)
		#expect(sut.callCounts.get == 1)
	}

	@Test("Preset tokens are readable without a save")
	func presetTokens() {
		let preset = MockKeychainRepository(presetTokens: [.profileId: "42"])

		#expect(preset.getSecret(for: .profileId)?.rawValue == "42")
		#expect(preset.callCounts.save == 0)
	}

	@Test("Simulated save failure returns false and stores nothing")
	func simulatedSaveFailure() {
		sut.simulateSaveFailure(true)

		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc")) == false)
		#expect(sut.getSecret(for: .jwtToken) == nil)
	}

	@Test("Simulated update failure returns false and keeps the old value")
	func simulatedUpdateFailure() {
		sut.presetToken(.jwtToken, value: "old")
		sut.simulateUpdateFailure(true)

		#expect(sut.updateSecret(SecretToken(type: .jwtToken, rawValue: "new")) == false)
		#expect(sut.getSecret(for: .jwtToken)?.rawValue == "old")
	}

	@Test("Simulated delete failure returns false and keeps the token")
	func simulatedDeleteFailure() {
		sut.presetToken(.jwtToken, value: "abc")
		sut.simulateDeleteFailure(true)

		#expect(sut.deleteSecret(for: .jwtToken) == false)
		#expect(sut.hasToken(for: .jwtToken))
	}

	@Test("Deleting a missing type succeeds")
	func deleteMissing() {
		#expect(sut.deleteSecret(for: .pushNotificationToken))
		#expect(sut.callCounts.delete == 1)
	}

	@Test("resetFailureSimulations restores normal behavior")
	func resetFailureSimulations() {
		sut.simulateSaveFailure(true)
		sut.resetFailureSimulations()

		#expect(sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc")))
	}

	@Test("An injected logger receives operations under the repository category")
	func injectedLoggerRecordsOperations() {
		let logger = MockLogger()
		let sut = MockKeychainRepository(logger: logger)

		_ = sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc"))
		_ = sut.getSecret(for: .jwtToken)

		#expect(logger.entries.count == 2)
		#expect(logger.entries.allSatisfy { $0.level == .debug && $0.category == .repository })
	}

	@Test("Simulated failures are logged as warnings")
	func simulatedFailureLoggedAsWarning() {
		let logger = MockLogger()
		let sut = MockKeychainRepository(logger: logger)
		sut.simulateSaveFailure(true)
		logger.reset()

		_ = sut.saveSecret(SecretToken(type: .jwtToken, rawValue: "abc"))

		#expect(logger.entries.map(\.level) == [.warning])
	}

	@Test("Logged messages never contain the secret value")
	func logsDoNotLeakSecrets() {
		let logger = MockLogger()
		let sut = MockKeychainRepository(logger: logger)

		_ = sut.saveSecret(SecretToken(type: .devicePassword, rawValue: "hunter2"))
		_ = sut.updateSecret(SecretToken(type: .devicePassword, rawValue: "hunter3"))

		#expect(!logger.entries.contains { $0.message.contains("hunter") })
	}

	@Test("Token description is masked")
	func tokenIsMasked() {
		sut.presetToken(.devicePassword, value: "secret")

		let token = sut.getSecret(for: .devicePassword)
		#expect(token.map { String(describing: $0) } == "***********")
	}
}
