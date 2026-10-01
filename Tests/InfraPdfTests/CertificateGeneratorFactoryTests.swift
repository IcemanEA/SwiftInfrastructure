//
//  CertificateGeneratorFactoryTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraPdf
import InfraTestSupport

@Suite("CertificateGeneratorFactory")
struct CertificateGeneratorFactoryTests {

	private let imageGenerator = MockPdfCertificateGenerator()
	private let pdfGenerator = MockPdfCertificateGenerator()

	private var sut: CertificateGeneratorFactory {
		CertificateGeneratorFactory(imageGenerator: imageGenerator, pdfGenerator: pdfGenerator)
	}

	@Test("Image templates route to the image generator", arguments: ["a.jpg", "a.jpeg", "a.png", "a.webp"])
	func imageTemplates(name: String) {
		let generator = sut.getGenerator(for: URL(fileURLWithPath: "/tmp/\(name)"))

		#expect(generator as AnyObject === imageGenerator)
	}

	@Test("PDF templates route to the PDF generator", arguments: ["a.pdf", "a.PDF"])
	func pdfTemplates(name: String) {
		let generator = sut.getGenerator(for: URL(fileURLWithPath: "/tmp/\(name)"))

		#expect(generator as AnyObject === pdfGenerator)
	}

	@Test("The returned generator is the one that receives the call")
	func routedCallReachesGenerator() async throws {
		let generator = sut.getGenerator(for: URL(fileURLWithPath: "/tmp/cert.pdf"))
		let data = CertificateData(fullName: "Jane Doe", position: .zero, fontColor: nil)

		_ = try await generator.generateCertificate(templateImagePath: "/tmp/cert.pdf", certificateData: data)

		#expect(pdfGenerator.recordedTemplatePaths == ["/tmp/cert.pdf"])
		#expect(imageGenerator.recordedTemplatePaths.isEmpty)
	}
}
