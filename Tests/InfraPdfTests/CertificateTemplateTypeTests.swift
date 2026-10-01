//
//  CertificateTemplateTypeTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraPdf

@Suite("CertificateTemplateType")
struct CertificateTemplateTypeTests {

	private static let cases: [(name: String, expected: CertificateTemplateType)] = [
		("template.pdf", .pdf),
		("template.PDF", .pdf),
		("template.jpg", .image),
		("template.JPEG", .image),
		("template.jpeg", .image),
		("template.png", .image),
		("template.PNG", .image),
		("template.gif", .image),
		("template", .image)
	]

	@Test("from(url:) dispatches on the path extension, case-insensitively", arguments: cases)
	func fromURL(name: String, expected: CertificateTemplateType) {
		let url = URL(fileURLWithPath: "/tmp/templates").appendingPathComponent(name)

		#expect(CertificateTemplateType.from(url: url) == expected)
	}

	@Test("from(filename:) dispatches on the suffix, case-insensitively", arguments: cases)
	func fromFilename(name: String, expected: CertificateTemplateType) {
		#expect(CertificateTemplateType.from(filename: name) == expected)
	}

	@Test("Remote URLs with a query dispatch on the path only")
	func remoteURLWithQuery() {
		let url = URL(string: "https://cdn.example.com/certs/template.pdf?v=3")!

		#expect(CertificateTemplateType.from(url: url) == .pdf)
	}
}
