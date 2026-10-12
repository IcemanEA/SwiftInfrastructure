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
/// Вход — упорядоченный список PostScript-имён по приоритету. Берётся первое имя,
/// которое система смогла загрузить. Если не нашлось ни одного, возвращается системный
/// шрифт и в лог пишется предупреждение со всеми элементами списка без изменений.
///
/// Запятая внутри элемента списка — наследие старых данных, а не контракт: такой элемент
/// разрезается по запятым, как раньше разрезалась вся строка с именем шрифта.
enum CertificateFontResolver {

	/// Возвращает первый доступный шрифт из списка или системный шрифт запрошенного размера.
	/// - Parameters:
	///   - fontNames: PostScript-имена по приоритету; элемент с запятыми трактуется как несколько имён подряд.
	///   - size: размер шрифта в пунктах.
	///   - logger: логгер для предупреждения о подмене.
	static func resolve(fontNames: [String], size: CGFloat, logger: LogManager) -> UIFont {
		for candidate in fontNames.flatMap(candidates(in:)) {
			if let font = UIFont(name: candidate, size: size) {
				return font
			}
		}

		logger.warning("Font not found for fontNames \(fontNames), using system font")
		return UIFont.systemFont(ofSize: size)
	}

	/// Разбивает элемент списка по запятым, обрезает пробелы и отбрасывает пустые части.
	static func candidates(in entry: String) -> [String] {
		entry
			.split(separator: ",", omittingEmptySubsequences: true)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}
}
