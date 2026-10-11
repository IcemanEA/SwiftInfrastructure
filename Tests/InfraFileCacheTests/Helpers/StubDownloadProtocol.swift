//
//  StubDownloadProtocol.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Foundation
import InfraTestSupport

/// A `URLProtocol` that answers download requests from per-path replies instead of the network.
///
/// Replies are keyed by URL path, so tests running in parallel stay isolated as long
/// as each uses a unique path. A reply can be delayed, which keeps a download in
/// flight long enough to pause, cancel or duplicate it.
final class StubDownloadProtocol: URLProtocol {

	struct Reply: Sendable {
		var statusCode = 200
		var body: Data
		/// Seconds before the response starts.
		var delay: TimeInterval = 0
		/// Number of pieces the body is delivered in.
		var chunks = 1
	}

	private static let replies = LockedState<[String: Reply]>([:])
	private static let requestCounts = LockedState<[String: Int]>([:])

	static func register(path: String, reply: Reply) {
		replies.withLock { $0[path] = reply }
	}

	static func unregister(path: String) {
		replies.withLock { _ = $0.removeValue(forKey: path) }
		requestCounts.withLock { _ = $0.removeValue(forKey: path) }
	}

	/// How many times the path has been requested.
	static func requestCount(path: String) -> Int {
		requestCounts.withLock { $0[path] ?? 0 }
	}

	/// A session configuration that routes every request through this protocol.
	static func makeConfiguration() -> URLSessionConfiguration {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [StubDownloadProtocol.self]
		return configuration
	}

	override class func canInit(with request: URLRequest) -> Bool {
		true
	}

	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	override func startLoading() {
		guard let path = request.url?.path else {
			client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
			return
		}
		Self.requestCounts.withLock { $0[path, default: 0] += 1 }

		guard let reply = Self.replies.withLock({ $0[path] }) else {
			client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
			return
		}

		if reply.delay > 0 {
			// Ответ приходит на поток загрузки, как требует URLProtocol.
			perform(#selector(deliver), with: nil, afterDelay: reply.delay)
		} else {
			deliver()
		}
	}

	override func stopLoading() {
		NSObject.cancelPreviousPerformRequests(withTarget: self)
	}

	@objc private func deliver() {
		guard let url = request.url, let reply = Self.replies.withLock({ $0[url.path] }) else { return }

		let response = HTTPURLResponse(
			url: url,
			statusCode: reply.statusCode,
			httpVersion: "HTTP/1.1",
			headerFields: ["Content-Length": "\(reply.body.count)"]
		)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

		let chunkSize = max(1, Int((Double(reply.body.count) / Double(max(reply.chunks, 1))).rounded(.up)))
		var offset = 0
		while offset < reply.body.count {
			let end = min(offset + chunkSize, reply.body.count)
			client?.urlProtocol(self, didLoad: reply.body.subdata(in: offset..<end))
			offset = end
		}
		client?.urlProtocolDidFinishLoading(self)
	}
}
