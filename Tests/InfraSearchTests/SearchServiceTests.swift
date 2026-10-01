//
//  SearchServiceTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Testing
import InfraSearch

@Suite("SearchService ranking")
struct SearchServiceTests {

	private let sut = SearchService()

	private func search(_ query: String, in items: [String: String]) async -> [String] {
		await sut.configure(items: items)
		return await sut.search(query: query)
	}

	// MARK: - Relevance tiers

	@Test("Exact match outranks prefix match")
	func exactBeatsPrefix() async {
		#expect(await search("ivanov", in: ["B": "ivanov", "A": "ivanova"]) == ["B", "A"])
	}

	@Test("Every-word prefix match outranks any-word prefix match")
	func everyWordBeatsAnyWord() async {
		#expect(await search("iv pe", in: ["Z": "petrov ivan", "A": "ivanov sidor"]) == ["Z", "A"])
	}

	@Test("Substring match ranks below word-prefix match")
	func substringBelowWordPrefix() async {
		#expect(await search("ivan", in: ["A": "xivanov", "B": "petr ivanov"]) == ["B", "A"])
	}

	@Test("Single-word query orders whole, prefix, word-prefix and substring tiers")
	func singleWordTiers() async {
		let items = [
			"D": "ab",
			"C": "abx",
			"B": "x abz",
			"A": "xaby",
			"Z": "unrelated"
		]

		#expect(await search("ab", in: items) == ["D", "C", "B", "A"])
	}

	@Test("Multi-word query orders whole, prefix, every-word, any-word and word-contains tiers")
	func multiWordTiers() async {
		let items = [
			"E": "ab cd",
			"D": "ab cdz",
			"C": "cdy aby",
			"B": "abw",
			"A": "xcdx",
			"Z": "unrelated"
		]

		#expect(await search("ab cd", in: items) == ["E", "D", "C", "B", "A"])
	}

	@Test("Matching is case-insensitive in both query and value")
	func caseInsensitive() async {
		#expect(await search("ivanov", in: ["A": "IVANOV"]) == ["A"])
		#expect(await search("IVANOV", in: ["A": "ivanov"]) == ["A"])
	}

	// MARK: - Limits

	@Test("Returns at most five results")
	func capOfFive() async {
		let items = Dictionary(uniqueKeysWithValues: (1...8).map { ("Item \($0)", "ivan \($0)") })

		#expect(await search("ivan", in: items).count == 5)
	}

	@Test("Empty query returns no results")
	func emptyQuery() async {
		#expect(await search("", in: ["A": "ivan"]).isEmpty)
	}

	@Test("An unconfigured service returns no results")
	func unconfigured() async {
		#expect(await sut.search(query: "ivan").isEmpty)
	}

	@Test("configure replaces the previous dataset")
	func configureReplaces() async {
		await sut.configure(items: ["Old": "ivan"])
		await sut.configure(items: ["New": "ivan"])

		#expect(await sut.search(query: "ivan") == ["New"])
	}

	// MARK: - Determinism

	@Test("Equal-score matches are ordered by display name")
	func tiesAreAlphabetical() async {
		let items = ["Zeta": "ivan z", "Alpha": "ivan a", "Mid": "ivan m"]

		for _ in 0..<10 {
			#expect(await search("ivan", in: items) == ["Alpha", "Mid", "Zeta"])
		}
	}

	@Test("The cap is applied after the tie-break")
	func capAfterTieBreak() async {
		let items = ["G": "ivan", "F": "ivan", "E": "ivan", "D": "ivan", "C": "ivan", "B": "ivan", "A": "ivan"]

		#expect(await search("ivan", in: items) == ["A", "B", "C", "D", "E"])
	}
}
