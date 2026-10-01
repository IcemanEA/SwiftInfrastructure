//
//  StubURLProtocol.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation

/// A `URLProtocol` that answers requests from per-path handlers instead of the network.
///
/// Handlers are keyed by URL path so tests running in parallel stay isolated
/// as long as each uses a unique path.
final class StubURLProtocol: URLProtocol {

	enum Reply {
		case response(URLResponse, Data)
		case failure(Error)
	}

	private static let lock = NSLock()
	nonisolated(unsafe) private static var handlers: [String: Reply] = [:]

	static func register(path: String, reply: Reply) {
		lock.lock()
		defer { lock.unlock() }
		handlers[path] = reply
	}

	static func unregister(path: String) {
		lock.lock()
		defer { lock.unlock() }
		handlers.removeValue(forKey: path)
	}

	private static func reply(for path: String) -> Reply? {
		lock.lock()
		defer { lock.unlock() }
		return handlers[path]
	}

	override class func canInit(with request: URLRequest) -> Bool {
		true
	}

	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	override func startLoading() {
		guard let path = request.url?.path, let reply = Self.reply(for: path) else {
			client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
			return
		}

		switch reply {
		case .response(let response, let data):
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		case .failure(let error):
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}
