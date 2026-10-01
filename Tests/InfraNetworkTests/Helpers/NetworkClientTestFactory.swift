//
//  NetworkClientTestFactory.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import InfraCore
import InfraNetwork
import InfraTestSupport

enum NetworkClientTestFactory {
	static let baseUrl = URL(string: "https://stub.example.com")!

	/// A client whose session routes every request through `StubURLProtocol`.
	static func makeClient() -> NetworkClient {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [StubURLProtocol.self]
		return NetworkClient(
			session: URLSession(configuration: configuration),
			requestBuilder: NetworkRequestBuilder(baseUrl: baseUrl),
			logger: LogManager(logger: MockLogger(), category: .network)
		)
	}

	/// Registers an HTTP reply for a fresh unique path and returns that path.
	static func stub(status: Int, body: Data = Data()) -> String {
		let path = "/\(UUID().uuidString)"
		let response = HTTPURLResponse(url: baseUrl.appendingPathComponent(path), statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
		StubURLProtocol.register(path: path, reply: .response(response, body))
		return path
	}
}
