//
//  SecretTokenTypeTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.10.2026.
//

import Testing
@testable import InfraKeychain

@Suite("SecretTokenType")
struct SecretTokenTypeTests {

	// Raw values are persisted as Keychain account suffixes. Changing one orphans secrets saved by earlier app versions.
	@Test("Raw values are stable", arguments: [
		(SecretTokenType.jwtToken, "jwt_token"),
		(.deviceUsername, "device_username"),
		(.devicePassword, "device_password"),
		(.profileId, "profile_id"),
		(.pushNotificationToken, "push_notification_token")
	])
	func rawValues(type: SecretTokenType, expected: String) {
		#expect(type.rawValue == expected)
	}

	@Test("Every case is covered by the raw-value test")
	func caseCount() {
		#expect(SecretTokenType.allCases.count == 5)
	}

	@Test("Credentials are critical, identifiers and push tokens are not")
	func isCritical() {
		#expect(SecretTokenType.jwtToken.isCritical)
		#expect(SecretTokenType.deviceUsername.isCritical)
		#expect(SecretTokenType.devicePassword.isCritical)
		#expect(SecretTokenType.profileId.isCritical == false)
		#expect(SecretTokenType.pushNotificationToken.isCritical == false)
	}
}
