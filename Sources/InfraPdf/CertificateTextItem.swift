//
//  CertificateTextItem.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 16.07.2025.
//

import Foundation

/// Single text item for certificate with individual styling and positioning
public struct CertificateTextItem {
	public let text: String
	public let position: CGPoint
	public let fontSize: CGFloat
	public let fontName: String
	public let fontColor: String
	
	public init(
		text: String,
		position: CGPoint,
		fontSize: CGFloat = 123.0,
		fontName: String = "HelveticaNeue-Bold",
		fontColor: String?
	) {
		self.text = text
		self.position = position
		self.fontSize = fontSize
		self.fontName = fontName
		self.fontColor = fontColor ?? "#000000"
	}
}
