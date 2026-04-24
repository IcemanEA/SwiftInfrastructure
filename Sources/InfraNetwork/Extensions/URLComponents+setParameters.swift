//
//  URLComponents+setParameters.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

extension URLComponents {
	/// Returns a copy of these components with `queryItems` set from the given dictionary.
	///
	/// - Parameter parameters: The query parameters to attach.
	/// - Returns: A new `URLComponents` value with the supplied parameters as query items.
	public func setParameters(_ parameters: [String: Any]) -> URLComponents {
		var urlComponents = self
		urlComponents.queryItems = parameters.map { URLQueryItem(name: $0, value: String(describing: $1)) }
		return urlComponents
	}
}
