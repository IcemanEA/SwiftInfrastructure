//
//  IPdfCertificateGenerator.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.07.2025.
//

import Foundation

/// Service for generating PDF certificates with text overlay on JPG templates
public protocol IPdfCertificateGenerator {
	/// Generate PDF certificate and preview from JPG template with overlaid text
	/// - Parameters:
	///   - templateImagePath: Path of JPG template file in Bundle
	///   - certificateData: Data containing text and positioning information
	/// - Returns: Tuple containing preview image data and PDF data
	/// - Throws: PdfGeneratorError if generation fails
	func generateCertificate(templateImagePath: String, certificateData: CertificateData) async throws -> (previewData: Data, pdfData: Data)
}
