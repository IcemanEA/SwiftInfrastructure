//
//  MaskStringConvertibleTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraCore

@Suite("MaskStringConvertible")
struct MaskStringConvertibleTests {

	private struct Credential: MaskStringConvertible {
		let secret: String
	}

	private let sut = Credential(secret: "hunter2")

	@Test("description and debugDescription are masked")
	func descriptionsAreMasked() {
		#expect(sut.description == "***********")
		#expect(sut.debugDescription == "***********")
	}

	@Test("String interpolation and String(describing:) never reveal the secret")
	func interpolationDoesNotLeak() {
		#expect("\(sut)" == "***********")
		#expect(!String(describing: sut).contains("hunter2"))
		#expect(!String(reflecting: sut).contains("hunter2"))
	}
}
