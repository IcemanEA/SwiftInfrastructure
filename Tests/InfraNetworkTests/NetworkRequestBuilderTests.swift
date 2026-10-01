//
//  NetworkRequestBuilderTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraNetwork

@Suite("NetworkRequestBuilder")
struct NetworkRequestBuilderTests {

	private let baseUrl = URL(string: "https://api.example.com/v1")!

	@Test("Appends the path to the base URL and sets the method", arguments: [HTTPMethod.get, .post, .put, .delete])
	func pathAndMethod(method: HTTPMethod) {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(method: method, path: "users/42"))

		#expect(request.url?.absoluteString == "https://api.example.com/v1/users/42")
		#expect(request.httpMethod == method.rawValue)
		#expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
	}

	@Test("Copies request headers")
	func headers() {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(path: "a", header: ["X-Trace": "abc"]))

		#expect(request.value(forHTTPHeaderField: "X-Trace") == "abc")
	}

	@Test("URL parameters become query items")
	func urlParameters() throws {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(path: "search", parameters: .url(["q": "swift", "page": 2])))

		let url = try #require(request.url)
		let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
		#expect(Set(items) == [URLQueryItem(name: "q", value: "swift"), URLQueryItem(name: "page", value: "2")])
		#expect(url.path == "/v1/search")
	}

	@Test("JSON body is serialized with a JSON content type")
	func jsonBody() throws {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(method: .post, path: "a", body: .json(["name": "Ann"])))

		let body = try #require(request.httpBody)
		let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
		#expect(object == ["name": "Ann"])
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
	}

	@Test("Raw data body keeps its bytes and declared content type")
	func dataBody() {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(method: .put, path: "a", body: .data(Data([1, 2, 3]), .png)))

		#expect(request.httpBody == Data([1, 2, 3]))
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "image/png")
	}

	@Test("Bearer token sets the Authorization header")
	func bearerToken() {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl, token: AuthToken(rawValue: "jwt"))

		let request = sut.build(forRequest: TestRequest(path: "a"))

		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
	}

	@Test("Basic auth takes precedence over a bearer token")
	func basicAuthWins() {
		let sut = NetworkRequestBuilder(
			baseUrl: baseUrl,
			token: AuthToken(rawValue: "jwt"),
			basicAuth: BasicAuth(username: "user", password: "pass")
		)

		let request = sut.build(forRequest: TestRequest(path: "a"))

		#expect(request.value(forHTTPHeaderField: "Authorization") == "Basic dXNlcjpwYXNz")
	}

	@Test("No credentials means no Authorization header")
	func noCredentials() {
		let sut = NetworkRequestBuilder(baseUrl: baseUrl)

		let request = sut.build(forRequest: TestRequest(path: "a"))

		#expect(request.value(forHTTPHeaderField: "Authorization") == nil)
	}
}
