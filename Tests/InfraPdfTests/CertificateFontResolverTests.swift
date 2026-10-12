//
//  CertificateFontResolverTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 07.10.2026.
//

import Testing
import UIKit
import InfraCore
import InfraTestSupport
@testable import InfraPdf

@Suite("CertificateFontResolver")
struct CertificateFontResolverTests {

	private let mockLogger = MockLogger()
	private let logger: LogManager

	init() {
		logger = LogManager(logger: mockLogger, category: .business)
	}

	private func resolve(_ fontNames: [String], size: CGFloat = 24) -> UIFont {
		CertificateFontResolver.resolve(fontNames: fontNames, size: size, logger: logger)
	}

	private var warnings: [MockLogger.Entry] {
		mockLogger.entries.filter { $0.level == .warning }
	}

	@Test("A single installed name resolves to that font at the requested size")
	func singleInstalledName() {
		let font = resolve(["Courier"], size: 24)

		#expect(font.fontName == "Courier")
		#expect(font.pointSize == 24)
		#expect(warnings.isEmpty)
	}

	@Test("The first entry wins when it is installed")
	func firstEntryInstalled() {
		let font = resolve(["Courier", "HelveticaNeue-Bold"])

		#expect(font.fontName == "Courier")
		#expect(warnings.isEmpty)
	}

	@Test("The first installed entry wins when the first entry is missing")
	func firstMissingSecondInstalled() {
		let font = resolve(["NoSuchFont-Bold", "HelveticaNeue-Bold"])

		#expect(font.fontName == "HelveticaNeue-Bold")
		#expect(warnings.isEmpty)
	}

	@Test("Order decides when several entries are installed")
	func orderAmongInstalled() {
		let font = resolve(["HelveticaNeue-Bold", "Courier"])

		#expect(font.fontName == "HelveticaNeue-Bold")
		#expect(warnings.isEmpty)
	}

	@Test("A comma inside an entry still splits it into several names")
	func commaInsideEntry() {
		let font = resolve(["NoSuchFont-Bold, Courier"])

		#expect(font.fontName == "Courier")
		#expect(warnings.isEmpty)
	}

	@Test("Whitespace and empty pieces across entries are ignored")
	func whitespaceAndEmptyEntries() {
		let font = resolve(["  ", " , NoSuchFont-Bold ,, Courier  ,", "HelveticaNeue-Bold"])

		#expect(font.fontName == "Courier")
		#expect(warnings.isEmpty)
	}

	@Test("No resolvable entry falls back to the system font and logs one warning with every entry unmodified")
	func noEntryResolves() {
		let font = resolve(["NoSuchFont-Bold, AlsoMissing", "Missing-Too"], size: 30)

		#expect(font == UIFont.systemFont(ofSize: 30))
		#expect(warnings.count == 1)
		#expect(warnings.first?.message.contains("NoSuchFont-Bold, AlsoMissing") == true)
		#expect(warnings.first?.message.contains("Missing-Too") == true)
		#expect(warnings.first?.category == .business)
	}

	@Test("An empty list falls back to the system font and logs one warning")
	func emptyList() {
		let font = resolve([], size: 18)

		#expect(font == UIFont.systemFont(ofSize: 18))
		#expect(warnings.count == 1)
	}

	@Test("Blank entries only fall back to the system font", arguments: [[""], [" , , ", "  "]])
	func blankEntries(fontNames: [String]) {
		let font = resolve(fontNames, size: 18)

		#expect(font == UIFont.systemFont(ofSize: 18))
		#expect(warnings.count == 1)
	}

	@Test("Candidates are trimmed and empty pieces dropped")
	func candidates() {
		#expect(CertificateFontResolver.candidates(in: "Courier") == ["Courier"])
		#expect(CertificateFontResolver.candidates(in: " A , ,B,, C ") == ["A", "B", "C"])
		#expect(CertificateFontResolver.candidates(in: " , , ").isEmpty)
	}
}
