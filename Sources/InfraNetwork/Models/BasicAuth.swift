//
//  BasicAuth.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A `username` / `password` pair used for HTTP Basic authentication, typically on registration requests.
public struct BasicAuth {
	public let username: String
	public let password: String

	public init(username: String, password: String) {
		self.username = username
		self.password = password
	}

	/// The Base64-encoded `username:password` string used in the `Authorization` header.
	public var encodedCredentials: String {
		let credentials = "\(username):\(password)"
		let credentialsData = credentials.data(using: .utf8)!
		return credentialsData.base64EncodedString()
	}

	/// The full `Authorization: Basic …` header value.
	public var authorizationHeader: String {
		return "Basic \(encodedCredentials)"
	}
}
