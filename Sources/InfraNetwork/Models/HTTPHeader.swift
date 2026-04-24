//
//  HTTPHeader.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

public typealias HTTPHeader = [String: String]

/// Frequently used HTTP header fields, modelled so call sites don't hand-roll header strings.
public enum HeaderField {
	/// The `Authorization: Basic …` header built from a ``BasicAuth`` pair.
	case basicAuth(BasicAuth)

	/// The `Authorization: Bearer …` header carrying an ``AuthToken``.
	case authorization(AuthToken)

	/// The `Content-Type` header.
	case contentType(ContentType)

	/// The canonical HTTP header name for this field.
	public var key: String {
		switch self {
		case .basicAuth:
			return "Authorization"
		case .authorization:
			return "Authorization"
		case .contentType:
			return "Content-Type"
		}
	}
	
	/// The rendered header value for this field.
	public var value: String {
		switch self {
		case .basicAuth(let basicAuth):
			return basicAuth.authorizationHeader
		case .authorization(let token):
			return "Bearer \(token.rawValue)"
		case .contentType(let contentType):
			return contentType.value
		}
	}
}
