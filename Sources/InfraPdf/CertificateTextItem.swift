//
//  CertificateTextItem.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 16.07.2025.
//

import Foundation

/// Single text item for certificate with individual styling and positioning
public struct CertificateTextItem: Sendable {
	public let text: String
	public let position: CGPoint
	public let fontSize: CGFloat
	/// Упорядоченный список PostScript-имён шрифтов по приоритету.
	///
	/// Используется первое имя, которое система смогла загрузить. Если не загрузилось
	/// ни одно, поле рисуется системным шрифтом того же размера.
	public let fontNames: [String]
	public let fontColor: String
	
	public init(
		text: String,
		position: CGPoint,
		fontSize: CGFloat = 123.0,
		fontNames: [String] = ["HelveticaNeue-Bold"],
		fontColor: String?
	) {
		self.text = text
		self.position = position
		self.fontSize = fontSize
		self.fontNames = fontNames
		self.fontColor = fontColor ?? "#000000"
	}
}
