//
//  CertificateGeneratorFallbackTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 07.10.2026.
//

import Foundation
import Testing
import UIKit
import InfraPdf
import InfraTestSupport

@Suite("Certificate generators fall back to the system font")
struct CertificateGeneratorFallbackTests {

	private let directory: URL
	private let logger = MockLogger()

	init() throws {
		directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("CertificateGeneratorFallbackTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func cleanUp() {
		try? FileManager.default.removeItem(at: directory)
	}

	private var warnings: [MockLogger.Entry] {
		logger.entries.filter { $0.level == .warning }
	}

	private func certificateData(fontName: String) -> CertificateData {
		CertificateData(textItems: [
			CertificateTextItem(
				text: "Jane Doe",
				position: CGPoint(x: 100, y: 100),
				fontSize: 24,
				fontName: fontName,
				fontColor: "#000000"
			)
		])
	}

	private func writePngTemplate() throws -> URL {
		let url = directory.appendingPathComponent("template.png")
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
			UIColor.white.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
		}
		let data = try #require(image.pngData())
		try data.write(to: url)
		return url
	}

	private func writePdfTemplate() throws -> URL {
		let url = directory.appendingPathComponent("template.pdf")
		let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
		let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
			context.beginPage()
			UIColor.white.setFill()
			context.fill(bounds)
		}
		try data.write(to: url)
		return url
	}

	@Test("Image-template generator renders an item with an unknown font and logs one warning")
	func imageGeneratorFallsBack() async throws {
		defer { cleanUp() }
		let template = try writePngTemplate()
		let sut = PdfCertificateGenerator(logger: logger)

		let output = try await sut.generateCertificate(
			templateImagePath: template.path,
			certificateData: certificateData(fontName: "NoSuchFont-Bold")
		)

		#expect(!output.previewData.isEmpty)
		#expect(!output.pdfData.isEmpty)
		#expect(warnings.count == 1)
		#expect(warnings.first?.message.contains("NoSuchFont-Bold") == true)
	}

	@Test("PDF-template generator renders an item with an unknown font and logs one warning")
	func pdfGeneratorFallsBack() async throws {
		defer { cleanUp() }
		let template = try writePdfTemplate()
		let sut = PdfTemplateCertificateGenerator(logger: logger)

		let output = try await sut.generateCertificate(
			templateImagePath: template.path,
			certificateData: certificateData(fontName: "NoSuchFont-Bold")
		)

		#expect(!output.previewData.isEmpty)
		#expect(!output.pdfData.isEmpty)
		#expect(warnings.count == 1)
		#expect(warnings.first?.message.contains("NoSuchFont-Bold") == true)
	}

	@Test("Both generators resolve a later list entry without a warning")
	func bothGeneratorsResolveLaterEntry() async throws {
		defer { cleanUp() }
		let png = try writePngTemplate()
		let pdf = try writePdfTemplate()
		let data = certificateData(fontName: "NoSuchFont-Bold, Courier")

		_ = try await PdfCertificateGenerator(logger: logger)
			.generateCertificate(templateImagePath: png.path, certificateData: data)
		_ = try await PdfTemplateCertificateGenerator(logger: logger)
			.generateCertificate(templateImagePath: pdf.path, certificateData: data)

		#expect(warnings.isEmpty)
	}
}
