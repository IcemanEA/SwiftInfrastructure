//
//  CertificateData.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.07.2025.
//

import Foundation

/// Data structure for certificate text positioning and styling
public struct CertificateData {
	public let textItems: [CertificateTextItem]
	
	public init(textItems: [CertificateTextItem]) {
		self.textItems = textItems
	}
	
	/// Convenience initializer for single text item (backward compatibility)
	public init(
		fullName: String,
		position: CGPoint,
		fontSize: CGFloat = 123.0,
		fontName: String = "HelveticaNeue-Bold",
		fontColor: String?
	) {
		let textItem = CertificateTextItem(
			text: fullName,
			position: position,
			fontSize: fontSize,
			fontName: fontName,
			fontColor: fontColor
		)
		self.textItems = [textItem]
	}
}
