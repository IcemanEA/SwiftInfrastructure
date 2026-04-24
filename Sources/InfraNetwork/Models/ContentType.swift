//
//  ContentType.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A MIME content type used for HTTP request bodies and `Content-Type` headers.
public enum ContentType {
	/// JSON — `application/json`.
	case json
	/// Markdown text — `text/markdown`.
	case markdown
	/// URL-encoded form data — `application/x-www-form-urlencoded`.
	case urlEncoded
	/// Multipart form data with a caller-supplied boundary.
	case multipart(boundary: String)
	/// JPEG image — `image/jpeg`.
	case jpeg
	/// PNG image — `image/png`.
	case png

	/// The MIME string to place in the `Content-Type` header.
	public var value: String {
		switch self {
		case .json:
			return "application/json"
		case .markdown:
			return "text/markdown"
		case .urlEncoded:
			return "application/x-www-form-urlencoded"
		case .multipart(let boundary):
			return "multipart/form-data; boundary=\(boundary)"
		case .jpeg:
			return "image/jpeg"
		case .png:
			return "image/png"
		}
	}
}
