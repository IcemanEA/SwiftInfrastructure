//
//  URLRequestAddTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraNetwork

@Suite("URLRequest+Add")
struct URLRequestAddTests {

	private func makeRequest() -> URLRequest {
		URLRequest(url: URL(string: "https://example.com/path")!)
	}

	@Test("add(header:) sets the field's key and value")
	func addHeader() {
		var request = makeRequest()

		request.add(header: .contentType(.multipart(boundary: "XYZ")))

		#expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=XYZ")
	}

	@Test("add(body:) serializes a JSON object")
	func jsonBody() throws {
		var request = makeRequest()

		request.add(body: .json(["a": 1]))

		let object = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Int]
		#expect(object == ["a": 1])
	}

	@Test("add(body:) serializes a JSON array")
	func jsonArrayBody() throws {
		var request = makeRequest()

		request.add(body: .jsonArray([["a": 1], ["b": 2]]))

		let array = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [[String: Int]]
		#expect(array == [["a": 1], ["b": 2]])
	}

	@Test("add(body:) encodes form data as a query string")
	func formDataBody() throws {
		var request = makeRequest()

		request.add(body: .formData(["name": "Ann"]))

		#expect(String(data: try #require(request.httpBody), encoding: .utf8) == "name=Ann")
	}

	@Test("add(body:) passes raw data through")
	func dataBody() {
		var request = makeRequest()

		request.add(body: .data(Data([9]), .jpeg))

		#expect(request.httpBody == Data([9]))
	}

	@Test("add(parameters:) with .none leaves the URL unchanged")
	func noParameters() {
		var request = makeRequest()

		request.add(parameters: .none)

		#expect(request.url?.absoluteString == "https://example.com/path")
	}

	@Test("add(parameters:) with .url appends query items")
	func urlParameters() {
		var request = makeRequest()

		request.add(parameters: .url(["id": 7]))

		#expect(request.url?.absoluteString == "https://example.com/path?id=7")
	}
}

@Suite("URLComponents+setParameters")
struct URLComponentsSetParametersTests {

	@Test("Values are rendered with String(describing:)")
	func valuesAreDescribed() {
		let sut = URLComponents(string: "https://example.com")!

		let result = sut.setParameters(["flag": true, "count": 3, "name": "x"])

		#expect(Set(result.queryItems ?? []) == [
			URLQueryItem(name: "flag", value: "true"),
			URLQueryItem(name: "count", value: "3"),
			URLQueryItem(name: "name", value: "x")
		])
	}

	@Test("Returns a copy and leaves the original untouched")
	func returnsCopy() {
		let sut = URLComponents(string: "https://example.com")!

		_ = sut.setParameters(["a": 1])

		#expect(sut.queryItems == nil)
	}

	@Test("Empty dictionary yields an empty query item list")
	func emptyParameters() {
		let result = URLComponents(string: "https://example.com")!.setParameters([:])

		#expect(result.queryItems == [])
	}
}
