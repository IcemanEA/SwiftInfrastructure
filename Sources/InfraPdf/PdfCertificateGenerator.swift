//
//  PdfCertificateGenerator.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.07.2025.
//

import InfraCore
import SwiftUI
import UIKit

/// PDF certificate generator implementation using UIKit for JPG templates
public final class PdfCertificateGenerator: IPdfCertificateGenerator {

	// MARK: - Private Properties

	private let logger: LogManager

	// MARK: - Initialization

	/// - Parameter logger: логгер, в который генератор пишет предупреждения о подмене шрифта.
	public init(logger: ILogger) {
		self.logger = LogManager(logger: logger, category: .business)
	}

	// MARK: - Public Methods

	public func generateCertificate(templateImagePath: String, certificateData: CertificateData) async throws -> (previewData: Data, pdfData: Data) {
		let imageWithText = try await createImageWithText(imagePath: templateImagePath, certificateData: certificateData)
		
		// Создаем оптимизированное превью
		let previewData = createOptimizedPreview(from: imageWithText)
		
		// Создаем PDF
		let pdfData = createPDFFromImage(imageWithText)
		
		return (previewData: previewData, pdfData: pdfData)
	}
	
	// MARK: - Private Methods
	
	private func loadTemplateImage(imagePath path: String) throws -> UIImage {
		let cleanPath = path.hasPrefix("file://") ? String(path.dropFirst(7)) : path
		
		// Загружаем как Data, чтобы контролировать scale
		guard let imageData = NSData(contentsOfFile: cleanPath) else {
			throw PdfGeneratorError.templateImageNotFound(cleanPath)
		}
		
		// Создаем UIImage с фиксированным scale = 1.0 для консистентности
		guard let image = UIImage(data: imageData as Data, scale: 1.0) else {
			throw PdfGeneratorError.invalidTemplateImage
		}
		
		guard image.size.width > 0 && image.size.height > 0 else {
			throw PdfGeneratorError.invalidTemplateImage
		}
		
		return image
	}
	
	private func createImageWithText(
		imagePath: String,
		certificateData: CertificateData
	) async throws -> UIImage {
		 return try await withCheckedThrowingContinuation { continuation in
			 Task {
				 do {
					 let templateImage = try loadTemplateImage(imagePath: imagePath)
					 let imageWithText = addTextToImage(templateImage, certificateData: certificateData)
					 continuation.resume(returning: imageWithText)
				 } catch {
					 continuation.resume(throwing: error)
				 }
			 }
		 }
	 }

	private func createPDFFromImage(_ image: UIImage) -> Data {
		let pageSize = image.size
		
		let format = UIGraphicsPDFRendererFormat()
		let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
		
		return renderer.pdfData { context in
			context.beginPage()
			
			// Отрисовываем изображение с фиксированной компрессией
			if let compressedData = image.jpegData(compressionQuality: 1.0),
			   let compressedImage = UIImage(data: compressedData, scale: 1.0) {
				compressedImage.draw(in: CGRect(origin: .zero, size: pageSize))
			} else {
				image.draw(in: CGRect(origin: .zero, size: pageSize))
			}
		}
	}
	
	private func addTextToImage(_ templateImage: UIImage, certificateData: CertificateData) -> UIImage {
		// Создаем format с фиксированным scale = 1.0
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1.0
		
		let renderer = UIGraphicsImageRenderer(size: templateImage.size, format: format)
		
		return renderer.image { context in
			// Draw original template image
			templateImage.draw(at: .zero)
			
			// Draw all text overlays
			drawTextOverlays(in: context.cgContext, imageSize: templateImage.size, certificateData: certificateData)
		}
	}
	
	private func drawTextOverlays(in context: CGContext, imageSize: CGSize, certificateData: CertificateData) {
		for textItem in certificateData.textItems {
			drawTextOverlay(in: context, imageSize: imageSize, textItem: textItem)
		}
	}
	
	private func drawTextOverlay(in context: CGContext, imageSize: CGSize, textItem: CertificateTextItem) {
		let font = CertificateFontResolver.resolve(fontName: textItem.fontName, size: textItem.fontSize, logger: logger)
		
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: UIColor(hex: textItem.fontColor) ?? UIColor.black
		]
		
		let attributedString = NSAttributedString(string: textItem.text, attributes: attributes)
		let textSize = attributedString.size()
		
		// Simple UI coordinates (Y from top to bottom)
		let textRect = CGRect(
			x: textItem.position.x - textSize.width / 2,
			y: textItem.position.y - textSize.height / 2,
			width: textSize.width,
			height: textSize.height
		)
		
		attributedString.draw(in: textRect)
	}
	
	private func createOptimizedPreview(from originalImage: UIImage) -> Data {
		// Максимальные размеры для превью (сохраняем пропорции)
		let maxWidth: CGFloat = 1920
		let maxHeight: CGFloat = 1080
		
		let originalSize = originalImage.size
		let aspectRatio = originalSize.width / originalSize.height
		
		var newSize: CGSize
		
		if originalSize.width > maxWidth || originalSize.height > maxHeight {
			if aspectRatio > 1 {
				// Ландшафт - ограничиваем по ширине
				newSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
			} else {
				// Портрет - ограничиваем по высоте
				newSize = CGSize(width: maxHeight * aspectRatio, height: maxHeight)
			}
		} else {
			// Изображение уже оптимального размера
			newSize = originalSize
		}
		
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1.0
		
		let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
		let optimizedImage = renderer.image { _ in
			originalImage.draw(in: CGRect(origin: .zero, size: newSize))
		}
		
		return optimizedImage.jpegData(compressionQuality: 0.6) ?? Data()
	}
}

// MARK: UIColor + .init(hex)

extension UIColor {
	/// Creates a `UIColor` from a hex string, accepting the formats `"RRGGBB"`, `"#RRGGBB"`, and `"AARRGGBB"`.
	convenience init?(hex: String) {
		let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		let scanner = Scanner(string: hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString)
		
		var hexNumber: UInt64 = 0
		guard scanner.scanHexInt64(&hexNumber) else { return nil }
		
		let r, g, b, a: CGFloat
		let length = hexString.count - (hexString.hasPrefix("#") ? 1 : 0)
		
		if length == 6 {
			r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
			g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
			b = CGFloat(hexNumber & 0x0000FF) / 255
			a = 1.0
		} else if length == 8 {
			a = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
			r = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
			g = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
			b = CGFloat(hexNumber & 0x000000FF) / 255
		} else {
			return nil
		}
		
		self.init(red: r, green: g, blue: b, alpha: a)
	}
}
