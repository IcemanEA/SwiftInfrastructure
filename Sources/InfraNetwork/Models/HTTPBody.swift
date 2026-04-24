//
//  HTTPBody.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// The body payload of an HTTP request.
public enum HTTPBody {
	/// A JSON object represented as a dictionary.
	case json([String: Any])
	/// URL-encoded form data — usually used for `POST`ing HTML forms. Values are supplied as a dictionary.
	case formData([String: Any])
	/// A JSON array of objects.
	case jsonArray([[String: Any]])
	/// Arbitrary binary data with an explicit content type.
	case data(Data, ContentType)
	
	public var contentType: ContentType? {
		switch self {
		case let .data(_, type):
			type
		case .formData:
			.urlEncoded
		case .json, .jsonArray:
			.json
		}
	}
}
