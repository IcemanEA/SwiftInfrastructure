//
//  SearchService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.02.2026.
//

import Foundation

/// The default ``ISearchService`` implementation.
///
/// ## Overview
///
/// Returns up to five matches ranked by relevance. Search runs against the
/// `searchString` values and returns the matching `displayName` keys.
///
/// ## Ranking priorities
///
/// 1. Exact whole-string match.
/// 2. The searched value starts with the query.
/// 3. Every word of a multi-word query matches a prefix of a distinct word in the value.
/// 4. Any individual word of the value starts with the query.
/// 5. Any word of a multi-word query matches a prefix of any word of the value.
/// 6. The value contains the query as a substring.
/// 7. Any word of the value contains any word of the query.
///
/// Matches with the same priority are ordered by `displayName` ascending, so the
/// result is stable across calls and process launches.
public actor SearchService: ISearchService {

	// MARK: - Private Properties

	private var items: [String: String] = [:]

	// MARK: - Initialization

	public init() {}

	// MARK: - ISearchService Implementation

	public func configure(items: [String: String]) {
		self.items = items
	}

	public func search(query: String) -> [String] {
		guard !query.isEmpty else { return [] }
		let lowercasedQuery = query.lowercased()
		let queryWords = lowercasedQuery.split(separator: " ").map(String.init)

		var scored: [(key: String, score: Int)] = []

		for (displayName, searchString) in items {
			let value = searchString.lowercased()
			let valueWords = value.split(separator: " ").map(String.init)

			if value == lowercasedQuery {
				scored.append((displayName, 0))
			} else if value.hasPrefix(lowercasedQuery) {
				scored.append((displayName, 1))
			} else if queryWords.count > 1, allWordsMatchPrefixes(queryWords: queryWords, valueWords: valueWords) {
				scored.append((displayName, 2))
			} else if valueWords.contains(where: { $0.hasPrefix(lowercasedQuery) }) {
				scored.append((displayName, 3))
			} else if queryWords.count > 1, anyWordMatchesPrefix(queryWords: queryWords, valueWords: valueWords) {
				scored.append((displayName, 4))
			} else if value.contains(lowercasedQuery) {
				scored.append((displayName, 5))
			} else if valueWords.contains(where: { word in queryWords.contains(where: { word.contains($0) }) }) {
				scored.append((displayName, 6))
			}
		}

		return scored
			.sorted { ($0.score, $0.key) < ($1.score, $1.key) }
			.prefix(5)
			.map(\.key)
	}

	// MARK: - Private Methods

	private func allWordsMatchPrefixes(queryWords: [String], valueWords: [String]) -> Bool {
		var usedIndices = Set<Int>()
		for queryWord in queryWords {
			guard let index = valueWords.indices.first(where: {
				!usedIndices.contains($0) && valueWords[$0].hasPrefix(queryWord)
			}) else {
				return false
			}
			usedIndices.insert(index)
		}
		return true
	}

	private func anyWordMatchesPrefix(queryWords: [String], valueWords: [String]) -> Bool {
		queryWords.contains { queryWord in
			valueWords.contains { $0.hasPrefix(queryWord) }
		}
	}
}
