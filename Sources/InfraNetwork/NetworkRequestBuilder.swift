//
//  NetworkRequestBuilder.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A builder that assembles a `URLRequest` from an ``INetworkRequest``.
public protocol INetworkRequestBuilder {

	/// The base URL against which each request's path is resolved.
	var baseUrl: URL { get }

	/// Builds a `URLRequest` for the given ``INetworkRequest``.
	func build(forRequest request: INetworkRequest) -> URLRequest
}

/// A concrete request builder that composes a `URLRequest` from a domain `NetworkRequest` and optional credentials.
public struct NetworkRequestBuilder: INetworkRequestBuilder {
	/// The base URL of the service that receives requests built by this builder.
	public let baseUrl: URL
	private let token: AuthToken?
	private let basicAuth: BasicAuth?

	public init(baseUrl: URL, token: AuthToken? = nil, basicAuth: BasicAuth? = nil) {
		self.baseUrl = baseUrl
		self.token = token
		self.basicAuth = basicAuth
	}

	/// Assembles a `URLRequest` from the given domain request.
	///
	/// - Parameter request: The network request to assemble.
	/// - Returns: The assembled `URLRequest` with method, headers, parameters, body, and auth applied.
	public func build(forRequest request: INetworkRequest) -> URLRequest {
		let url = baseUrl.appendingPathComponent(request.path)

		var urlRequest = URLRequest(url: url)

		urlRequest.httpMethod = request.method.rawValue
		urlRequest.allHTTPHeaderFields = request.header
		urlRequest.cachePolicy = .reloadIgnoringLocalCacheData

		if let parameters = request.parameters {
			urlRequest.add(parameters: parameters)
		}

		if let body = request.body {
			urlRequest.add(body: body)
		}

		if let contentType = request.body?.contentType {
			urlRequest.add(header: .contentType(contentType))
		}

		// Приоритет: сначала Basic Auth, потом JWT
		if let basicAuth = basicAuth {
			urlRequest.add(header: .basicAuth(basicAuth))
		} else if let token = token {
			urlRequest.add(header: .authorization(token))
		}

		return urlRequest
	}
}
