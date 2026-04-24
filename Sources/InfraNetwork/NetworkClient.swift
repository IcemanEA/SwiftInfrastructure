//
//  NetworkClient.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraCore

public protocol INetworkClient {
	func fetch<T: Decodable>(_ request: INetworkRequest) async -> Result<T, NetworkError>
}

public struct NetworkClient: INetworkClient {
	private let requestBuilder: INetworkRequestBuilder
	private let decoder: JSONDecoder
	private let logger: LogManager

	private var session: URLSession

	public init(session: URLSession, requestBuilder: INetworkRequestBuilder, logger: LogManager, decoder: JSONDecoder = JSONDecoder()) {
		self.session = session
		self.requestBuilder = requestBuilder
		self.logger = logger
		self.decoder = decoder
	}

	public func fetch<T: Decodable>(_ request: INetworkRequest) async -> Result<T, NetworkError> {
		let startTime = Date()

		var urlRequest = requestBuilder.build(forRequest: request)
		urlRequest.assumesHTTP3Capable = true

		logger.info("🌐 Starting request: \(request.method.rawValue) \(request.path)")

		do {
			let (data, response) = try await session.data(for: urlRequest)

			let duration = Date().timeIntervalSince(startTime)
			logger.info("⚡ Network Request completed in \(String(format: "%.3f", duration))s for \(request.path)")

			guard let urlResponse = response as? HTTPURLResponse else {
				logger.error("Invalid response type")
				return .failure(.invalidResponse(response))
			}

			logger.info("Response received: \(urlResponse.statusCode)")

			guard let status = ResponseStatus(rawValue: urlResponse.statusCode), status.isSuccess else {
				logger.error("Invalid status code: \(urlResponse.statusCode)")
				return .failure(.invalidStatusCode(urlResponse.statusCode, data))
			}

			// Special case for health check
			if urlResponse.statusCode == 204, let status = ResponseHealth(isOnline: true) as? T {
				return .success(status)
			}

			// For 204 No Content, consider it successful without expecting data
			if urlResponse.statusCode == 204 {
				// For endpoints that return 204, we need to return a success but can't decode empty data
				// This is typically used for endpoints like PUT /api/v1/user/token
				logger.info("Received 204 No Content - operation successful")

				// Create an empty response for Void return types or appropriate success indicator
				if T.self == EmptyResponse.self {
					return .success(EmptyResponse() as! T)
				}

				// If the expected type is not EmptyResponse, we have a type mismatch
				logger.error("Expected data for type \(T.self) but received 204 No Content")
				return .failure(.noData)
			}

			guard data.count != 0 else {
				logger.warning("No data received")
				return .failure(.noData)
			}

			do {
				let object = try decoder.decode(T.self, from: data)
				logger.info("Successfully decoded response")
				return .success(object)
			} catch {
				logger.error("Decode error: \(error.localizedDescription)")
				return .failure(.badDecode(error))
			}
		} catch {
			let duration = Date().timeIntervalSince(startTime)
			logger.error("⚡ Failed Network Request in \(String(format: "%.3f", duration))s: \(error.localizedDescription)")
			logger.error("Transport error: \(error.localizedDescription)")
			return .failure(.transportError(error))
		}
	}

	// MARK: - Private Helpers

	/// Returns a copy of the client that uses a different `URLSession`, useful for tests that swap in a mocked session.
	public func copy(session newSession: URLSession) -> Self {
		var apiClientCopy = self
		apiClientCopy.session = newSession
		return apiClientCopy
	}
}
