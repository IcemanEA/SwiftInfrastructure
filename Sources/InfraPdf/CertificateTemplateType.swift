//
//  CertificateTemplateType.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on [DATE].
//

import Foundation

/// The kind of certificate template the factory will dispatch to — a raster image or a PDF.
public enum CertificateTemplateType {
	case image
	case pdf

	/// Determines the template type from a URL's path extension.
	public static func from(url: URL) -> CertificateTemplateType {
		let pathExtension = url.pathExtension.lowercased()

		switch pathExtension {
		case "pdf":
			return .pdf
		case "jpg", "jpeg", "png":
			return .image
		default:
			return .image  // По умолчанию считаем изображением
		}
	}

	/// Determines the template type from a filename string.
	public static func from(filename: String) -> CertificateTemplateType {
		let lowercased = filename.lowercased()

		if lowercased.hasSuffix(".pdf") {
			return .pdf
		} else if lowercased.hasSuffix(".jpg") ||
		          lowercased.hasSuffix(".jpeg") ||
		          lowercased.hasSuffix(".png") {
			return .image
		} else {
			return .image  // По умолчанию
		}
	}
}
