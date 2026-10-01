//
//  NetworkClientTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraNetwork

@Suite("NetworkClient")
struct NetworkClientTests {

	private struct User: Decodable, Equatable {
		let id: Int
		let name: String
	}

	private let sut = NetworkClientTestFactory.makeClient()

	private func request(_ path: String) -> NetworkRequest {
		NetworkRequest(method: .get, path: path)
	}

	@Test("200 with a valid body decodes the value")
	func decodesSuccess() async throws {
		let path = NetworkClientTestFactory.stub(status: 200, body: Data(#"{"id":1,"name":"Ann"}"#.utf8))
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		#expect(try result.get() == User(id: 1, name: "Ann"))
	}

	@Test("204 decodes as EmptyResponse")
	func noContentEmptyResponse() async throws {
		let path = NetworkClientTestFactory.stub(status: 204)
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<EmptyResponse, NetworkError> = await sut.fetch(request(path))

		_ = try result.get()
	}

	@Test("204 decodes as an online ResponseHealth")
	func noContentHealth() async throws {
		let path = NetworkClientTestFactory.stub(status: 204)
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<ResponseHealth, NetworkError> = await sut.fetch(request(path))

		#expect(try result.get().isOnline)
	}

	@Test("204 for any other type fails with noData")
	func noContentOtherType() async {
		let path = NetworkClientTestFactory.stub(status: 204)
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.noData) = result else {
			Issue.record("Expected .noData, got \(result)")
			return
		}
	}

	@Test("2xx with an empty body fails with noData")
	func emptyBody() async {
		let path = NetworkClientTestFactory.stub(status: 200)
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.noData) = result else {
			Issue.record("Expected .noData, got \(result)")
			return
		}
	}

	@Test("2xx with an undecodable body fails with badDecode")
	func undecodableBody() async {
		let path = NetworkClientTestFactory.stub(status: 200, body: Data("not json".utf8))
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.badDecode) = result else {
			Issue.record("Expected .badDecode, got \(result)")
			return
		}
	}

	@Test("Non-2xx status fails with invalidStatusCode carrying the body", arguments: [304, 401, 404, 500, 503])
	func invalidStatusCode(status: Int) async {
		let body = Data(#"{"error":"x"}"#.utf8)
		let path = NetworkClientTestFactory.stub(status: status, body: body)
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.invalidStatusCode(let code, let data)) = result else {
			Issue.record("Expected .invalidStatusCode, got \(result)")
			return
		}
		#expect(code == status)
		#expect(data == body)
	}

	@Test("A non-HTTP response fails with invalidResponse")
	func nonHTTPResponse() async {
		let path = "/\(UUID().uuidString)"
		let url = NetworkClientTestFactory.baseUrl.appendingPathComponent(path)
		let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
		StubURLProtocol.register(path: path, reply: .response(response, Data("{}".utf8)))
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.invalidResponse) = result else {
			Issue.record("Expected .invalidResponse, got \(result)")
			return
		}
	}

	@Test("A transport failure fails with transportError")
	func transportError() async {
		let path = "/\(UUID().uuidString)"
		StubURLProtocol.register(path: path, reply: .failure(URLError(.notConnectedToInternet)))
		defer { StubURLProtocol.unregister(path: path) }

		let result: Result<User, NetworkError> = await sut.fetch(request(path))

		guard case .failure(.transportError(let error)) = result else {
			Issue.record("Expected .transportError, got \(result)")
			return
		}
		#expect((error as? URLError)?.code == .notConnectedToInternet)
	}

	@Test("copy(session:) routes requests through the new session")
	func copySession() async throws {
		let path = NetworkClientTestFactory.stub(status: 200, body: Data(#"{"id":2,"name":"Bo"}"#.utf8))
		defer { StubURLProtocol.unregister(path: path) }
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [StubURLProtocol.self]

		let copy = sut.copy(session: URLSession(configuration: configuration))
		let result: Result<User, NetworkError> = await copy.fetch(request(path))

		#expect(try result.get() == User(id: 2, name: "Bo"))
	}
}
