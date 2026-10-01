//
//  CertificateDataTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraPdf

@Suite("CertificateData")
struct CertificateDataTests {

	@Test("Convenience initializer maps every field into a single text item")
	func convenienceInitializer() throws {
		let sut = CertificateData(
			fullName: "Jane Doe",
			position: CGPoint(x: 10, y: 20),
			fontSize: 48,
			fontName: "Courier",
			fontColor: "#FF0000"
		)

		let item = try #require(sut.textItems.first)
		#expect(sut.textItems.count == 1)
		#expect(item.text == "Jane Doe")
		#expect(item.position == CGPoint(x: 10, y: 20))
		#expect(item.fontSize == 48)
		#expect(item.fontName == "Courier")
		#expect(item.fontColor == "#FF0000")
	}

	@Test("Defaults apply when optional styling is omitted")
	func defaults() throws {
		let sut = CertificateData(fullName: "Jane Doe", position: .zero, fontColor: nil)

		let item = try #require(sut.textItems.first)
		#expect(item.fontSize == 123)
		#expect(item.fontName == "HelveticaNeue-Bold")
		#expect(item.fontColor == "#000000")
	}
}
