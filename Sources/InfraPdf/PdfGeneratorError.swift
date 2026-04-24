//
//  PdfGeneratorError.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.07.2025.
//

import Foundation

public enum PdfGeneratorError: LocalizedError {
	case templateImageNotFound(String)
	case invalidTemplateImage
	case pdfGenerationFailed
	case invalidFontName(String)

	public var errorDescription: String? {
		switch self {
		case .templateImageNotFound(let path):
			return "Template not found at path: \(path)"
		case .invalidTemplateImage:
			return "Invalid template image or PDF"
		case .pdfGenerationFailed:
			return "Failed to generate PDF document"
		case .invalidFontName(let fontName):
			return "Invalid font name: \(fontName)"
		}
	}
}
