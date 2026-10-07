//
//  CertificateFontResolver.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 07.10.2026.
//

import InfraCore
import UIKit

/// Подбирает шрифт для текстового поля сертификата.
///
/// `fontName` трактуется как список PostScript-имён через запятую в порядке приоритета.
/// Берётся первое имя, которое система смогла загрузить. Если не нашлось ни одного,
/// возвращается системный шрифт и в лог пишется предупреждение с исходной строкой.
enum CertificateFontResolver {

	/// Возвращает первый доступный шрифт из списка или системный шрифт запрошенного размера.
	/// - Parameters:
	///   - fontName: одно PostScript-имя или список имён через запятую.
	///   - size: размер шрифта в пунктах.
	///   - logger: логгер для предупреждения о подмене.
	static func resolve(fontName: String, size: CGFloat, logger: LogManager) -> UIFont {
		for candidate in candidates(in: fontName) {
			if let font = UIFont(name: candidate, size: size) {
				return font
			}
		}

		logger.warning("Font not found for fontName \"\(fontName)\", using system font")
		return UIFont.systemFont(ofSize: size)
	}

	/// Разбивает строку по запятым, обрезает пробелы и отбрасывает пустые элементы.
	static func candidates(in fontName: String) -> [String] {
		fontName
			.split(separator: ",", omittingEmptySubsequences: true)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}
}
