//
//  MockPdfCertificateGeneratorTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraPdf
import InfraTestSupport

@Suite("MockPdfCertificateGenerator")
struct MockPdfCertificateGeneratorTests {

	private let certificateData = CertificateData(
		fullName: "Jane Doe",
		position: .zero,
		fontNames: ["Panton-SemiBold", "Montserrat-Regular"],
		fontColor: nil
	)

	@Test("Returns the configured output and records the template path and certificate data")
	func configuredSuccess() async throws {
		let sut = MockPdfCertificateGenerator()
		sut.result = (previewData: Data([1]), pdfData: Data([2]))

		let output = try await sut.generateCertificate(templateImagePath: "template.png", certificateData: certificateData)

		#expect(output.previewData == Data([1]))
		#expect(output.pdfData == Data([2]))
		#expect(sut.recordedTemplatePaths == ["template.png"])
		#expect(sut.recordedCertificateData.count == 1)
		#expect(sut.recordedCertificateData.first?.textItems.first?.fontNames == ["Panton-SemiBold", "Montserrat-Regular"])
	}

	@Test("Throws the configured error and still records the call")
	func configuredFailure() async {
		let sut = MockPdfCertificateGenerator()
		sut.errorToThrow = PdfGeneratorError.pdfGenerationFailed

		await #expect(throws: PdfGeneratorError.self) {
			_ = try await sut.generateCertificate(templateImagePath: "broken.pdf", certificateData: certificateData)
		}
		#expect(sut.recordedTemplatePaths == ["broken.pdf"])
		#expect(sut.recordedCertificateData.count == 1)
	}
}
