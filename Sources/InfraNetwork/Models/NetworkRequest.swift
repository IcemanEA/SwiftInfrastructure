//
//  NetworkRequest.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A description of a single outbound network request.
public protocol INetworkRequest {
	/// The HTTP method of the request.
	var method: HTTPMethod { get }
	/// The path appended to the builder's base URL.
	var path: String { get }
	/// Optional HTTP headers for this request.
	var header: HTTPHeader? { get }
	/// Optional query parameters for this request.
	var parameters: Parameters? { get }
	/// Optional body payload for this request.
	var body: HTTPBody? { get }
}

/// Default `header` implementation so requests without custom headers don't need to spell out `nil`.
extension INetworkRequest {
	/// Default value for ``INetworkRequest/header`` — no custom headers.
	public var header: HTTPHeader? { nil }
}

public struct NetworkRequest: INetworkRequest {
	public var method: HTTPMethod
	public var path: String
	public var parameters: Parameters?
	public var body: HTTPBody?
	
	public init(method: HTTPMethod, path: String, parameters: Parameters? = nil, body: HTTPBody? = nil) {
		self.method = method
		self.path = path
		self.parameters = parameters
		self.body = body
	}
}
