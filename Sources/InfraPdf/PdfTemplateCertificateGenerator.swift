//
//  PdfTemplateCertificateGenerator.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on [DATE].
//

import PDFKit
import UIKit

/// PDF certificate generator for PDF templates using CGContext drawing
///
/// Generates certificates by drawing text directly into PDF content layer.
/// Text becomes part of the PDF content, not an annotation - can only be edited with special tools.
public final class PdfTemplateCertificateGenerator: IPdfCertificateGenerator {

	// MARK: - Initialization

	public init() {}

	// MARK: - Public Methods

	public func generateCertificate(
		templateImagePath: String,
		certificateData: CertificateData
	) async throws -> (previewData: Data, pdfData: Data) {

		return try await withCheckedThrowingContinuation { continuation in
			Task {
				do {
					// Load PDF template
					let cleanPath = templateImagePath.hasPrefix("file://")
						? String(templateImagePath.dropFirst(7))
						: templateImagePath

					guard let templateDocument = PDFDocument(url: URL(fileURLWithPath: cleanPath)) else {
						throw PdfGeneratorError.templateImageNotFound(templateImagePath)
					}

					guard let templatePage = templateDocument.page(at: 0) else {
						throw PdfGeneratorError.invalidTemplateImage
					}

					// Create new PDF with text drawn directly into content
					let pdfData = try drawTextIntoPDF(
						templatePage: templatePage,
						certificateData: certificateData
					)

					// Generate preview from result
					guard let resultDocument = PDFDocument(data: pdfData),
						  let resultPage = resultDocument.page(at: 0) else {
						throw PdfGeneratorError.pdfGenerationFailed
					}

					let previewData = createPreviewImage(from: resultPage)

					continuation.resume(returning: (previewData: previewData, pdfData: pdfData))

				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	// MARK: - Private Methods

	private func drawTextIntoPDF(
		templatePage: PDFPage,
		certificateData: CertificateData
	) throws -> Data {

		// Get page bounds
		var mediaBox = templatePage.bounds(for: .mediaBox)
		let pageHeight = mediaBox.size.height

		// Create PDF data
		let pdfData = NSMutableData()

		// Create PDF context
		guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
			throw PdfGeneratorError.pdfGenerationFailed
		}

		guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
			throw PdfGeneratorError.pdfGenerationFailed
		}

		// Begin PDF page
		context.beginPDFPage(nil)

		// Save state
		context.saveGState()

		// Draw original PDF template
		templatePage.draw(with: .mediaBox, to: context)

		// Restore state
		context.restoreGState()

		// Draw text directly into PDF content
		// Push graphics context for UIKit drawing
		UIGraphicsPushContext(context)

		// Save state before transformations
		context.saveGState()

		// Flip coordinate system for text drawing
		// PDF uses bottom-left origin with Y up, but text drawing expects top-left with Y down
		context.translateBy(x: 0, y: pageHeight)
		context.scaleBy(x: 1.0, y: -1.0)

		// Draw all text items
		for textItem in certificateData.textItems {
			drawTextDirectly(
				context: context,
				textItem: textItem
			)
		}

		// Restore state
		context.restoreGState()

		// Pop graphics context
		UIGraphicsPopContext()

		// End PDF page
		context.endPDFPage()

		// Close PDF
		context.closePDF()

		return pdfData as Data
	}

	private func drawTextDirectly(
		context: CGContext,
		textItem: CertificateTextItem
	) {
		guard let font = UIFont(name: textItem.fontName, size: textItem.fontSize) else {
			return
		}

		// Text attributes
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center

		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: UIColor(hex: textItem.fontColor) ?? UIColor.black,
			.paragraphStyle: paragraphStyle
		]

		// Calculate text size
		let attributedString = NSAttributedString(string: textItem.text, attributes: attributes)
		let textSize = attributedString.size()

		// Draw text centered at position
		// Note: we're already in flipped coordinate system (top-left origin, Y down)
		let drawRect = CGRect(
			x: textItem.position.x - textSize.width / 2,
			y: textItem.position.y - textSize.height / 2,
			width: textSize.width,
			height: textSize.height
		)

		textItem.text.draw(in: drawRect, withAttributes: attributes)
	}

	private func createPreviewImage(from page: PDFPage) -> Data {
		// Get page bounds
		let pageBounds = page.bounds(for: .mediaBox)

		// Calculate preview size (max 1920x1080, keep aspect ratio)
		let maxWidth: CGFloat = 1920
		let maxHeight: CGFloat = 1080

		let aspectRatio = pageBounds.width / pageBounds.height
		var previewSize: CGSize

		if aspectRatio > 1 {
			// Landscape - limit by width
			previewSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
		} else {
			// Portrait - limit by height
			previewSize = CGSize(width: maxHeight * aspectRatio, height: maxHeight)
		}

		// Don't upscale if original is smaller
		if pageBounds.width < previewSize.width && pageBounds.height < previewSize.height {
			previewSize = pageBounds.size
		}

		// Render PDF page as image with high quality
		let format = UIGraphicsImageRendererFormat()
		format.scale = 2.0  // 2x for better quality

		let renderer = UIGraphicsImageRenderer(size: previewSize, format: format)
		let image = renderer.image { context in
			// White background
			UIColor.white.setFill()
			context.fill(CGRect(origin: .zero, size: previewSize))

			// Save graphics state
			context.cgContext.saveGState()

			// Flip coordinate system back to normal for display
			// PDF is drawn upside down, so we need to flip it
			context.cgContext.translateBy(x: 0, y: previewSize.height)
			context.cgContext.scaleBy(x: 1.0, y: -1.0)

			// Scale to fit preview size
			let scaleX = previewSize.width / pageBounds.width
			let scaleY = previewSize.height / pageBounds.height
			context.cgContext.scaleBy(x: scaleX, y: scaleY)

			// Draw PDF page
			page.draw(with: .mediaBox, to: context.cgContext)

			// Restore graphics state
			context.cgContext.restoreGState()
		}

		return image.jpegData(compressionQuality: 0.8) ?? Data()
	}
}
