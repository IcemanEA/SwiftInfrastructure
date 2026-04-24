//
//  ISearchService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 15.02.2026.
//

import Foundation

/// An actor-isolated smart string-search service.
///
/// Search runs against `searchString` values but returns the matching
/// `displayName` keys, ranked by relevance. Implementations are actors to
/// guarantee serial access to the configured dataset.
public protocol ISearchService: Actor {
	/// Configures the service with the dataset to search over.
	///
	/// - Parameter items: A dictionary `[displayName: searchString]`. Search runs on the values; matches return the keys.
	func configure(items: [String: String])

	/// Runs a relevance-ranked search over the configured dataset.
	///
	/// - Parameter query: The search query.
	/// - Returns: Up to five matching `displayName` values, ordered by descending relevance.
	func search(query: String) -> [String]
}
