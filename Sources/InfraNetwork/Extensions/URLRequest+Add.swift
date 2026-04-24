//
//  URLRequest+Add.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

extension URLRequest {
	public mutating func add(header: HeaderField) {
		setValue(header.value, forHTTPHeaderField: header.key)
	}
	
	/// Sets the HTTP body of the request, serialising according to the ``HTTPBody`` variant.
	///
	/// - Parameter body: The body payload to attach.
	public mutating func add(body: HTTPBody) {
		switch body {
		case .json(let dictionary):
			httpBody = try? JSONSerialization.data(withJSONObject: dictionary)
		case .formData(let dictionary):
			httpBody = URLComponents().setParameters(dictionary).query?.data(using: .utf8)
		case .jsonArray(let array):
			httpBody = try? JSONSerialization.data(withJSONObject: array)
		case .data(let data, _):
			httpBody = data
		}
	}
	
	/// Applies request parameters — attaches query items for `.url` parameters; no-op for `.none`.
	///
	/// - Parameter parameters: The parameters to apply.
	public mutating func add(parameters: Parameters) {
		switch parameters {
		case .none:
			break
		case .url(let dictionary):
			guard let url = url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { break }
			components = components.setParameters(dictionary)
			guard let newUrl = components.url else { break }
			self.url = newUrl
		}
	}
}
