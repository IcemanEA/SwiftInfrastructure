//
//  DeviceCredentialsGeneratorTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraNetwork

@Suite("DeviceCredentialsGenerator")
struct DeviceCredentialsGeneratorTests {

	private let sut = DeviceCredentialsGenerator(osType: "ios", passwordSalt: "my-app-specific-salt-v1", usernamePrefix: "dev_")

	// MARK: - generatePassword

	@Suite("generatePassword")
	struct GeneratePassword {
		private let sut = DeviceCredentialsGenerator(osType: "ios", passwordSalt: "my-app-specific-salt-v1", usernamePrefix: "dev_")

		/// Golden value computed independently of the library:
		/// `printf '%s' 'dev_iaaaaaaaaaaaaaaaa|ios|my-app-specific-salt-v1' | shasum -a 256`
		/// = 168ac99e83ecde57741997033274dbf6a48e4056163a731064f1685644b7e038,
		/// composed as first 8 + hex[16..<20] + last 8 characters.
		@Test("Derivation matches the cross-platform golden value")
		func goldenValue() {
			#expect(sut.generatePassword(username: "dev_iaaaaaaaaaaaaaaaa") == "168ac99e741944b7e038")
		}

		@Test("Password is 20 lowercase hex characters")
		func passwordShape() {
			let password = sut.generatePassword(username: "dev_i0123456789abcdef")

			#expect(password.count == 20)
			#expect(password.allSatisfy { $0.isHexDigit && !$0.isUppercase })
		}

		@Test("The salt participates in the hash")
		func saltParticipates() {
			let other = DeviceCredentialsGenerator(osType: "ios", passwordSalt: "other-salt", usernamePrefix: "dev_")

			#expect(sut.generatePassword(username: "dev_iaaaaaaaaaaaaaaaa") != other.generatePassword(username: "dev_iaaaaaaaaaaaaaaaa"))
			#expect(other.generatePassword(username: "dev_iaaaaaaaaaaaaaaaa") == "5c950554486319294d23")
		}

		@Test("Username and osType are case-insensitive")
		func caseInsensitive() {
			let upperOS = DeviceCredentialsGenerator(osType: "IOS", passwordSalt: "my-app-specific-salt-v1", usernamePrefix: "dev_")

			#expect(sut.generatePassword(username: "DEV_IAAAAAAAAAAAAAAAA") == "168ac99e741944b7e038")
			#expect(upperOS.generatePassword(username: "dev_iaaaaaaaaaaaaaaaa") == "168ac99e741944b7e038")
		}
	}

	// MARK: - generateCredentials

	@Test("Generated username is prefix + OS letter + 16 lowercase hex characters")
	func usernameShape() {
		let (username, _) = sut.generateCredentials()

		#expect(username.hasPrefix("dev_i"))
		let suffix = username.dropFirst("dev_i".count)
		#expect(suffix.count == 16)
		#expect(suffix.allSatisfy { $0.isHexDigit && !$0.isUppercase })
	}

	@Test("Generated credentials validate against the same generator")
	func generatedCredentialsValidate() {
		let (username, password) = sut.generateCredentials()

		#expect(sut.validateCredentials(username: username, password: password))
		#expect(sut.generatePassword(username: username) == password)
	}

	@Test("Two calls produce different usernames")
	func usernamesAreRandom() {
		#expect(sut.generateCredentials().username != sut.generateCredentials().username)
	}

	// MARK: - Validation

	@Test("isValidDeviceUsername checks prefix and length", arguments: [
		("dev_iaaaaaaaaaaaaaaaa", true),
		("dev_iaaaaaaaaaaaaaaa", false),
		("dev_iaaaaaaaaaaaaaaaaa", false),
		("usr_iaaaaaaaaaaaaaaaa", false),
		("", false)
	])
	func usernameValidation(username: String, isValid: Bool) {
		#expect(sut.isValidDeviceUsername(username) == isValid)
	}

	@Test("validateCredentials rejects a wrong password")
	func wrongPassword() {
		#expect(sut.validateCredentials(username: "dev_iaaaaaaaaaaaaaaaa", password: "00000000000000000000") == false)
	}

	@Test("validateCredentials rejects a malformed username even with its derived password")
	func malformedUsername() {
		let username = "short"
		#expect(sut.validateCredentials(username: username, password: sut.generatePassword(username: username)) == false)
	}
}
