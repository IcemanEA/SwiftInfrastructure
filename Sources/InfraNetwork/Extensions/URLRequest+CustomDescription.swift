//
//  URLRequest+CustomDescription.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

extension URLRequest {
	public var customDescription: String {
		var printableDescription = ""
		
		if let method = self.httpMethod {
			printableDescription += method
		}
		if let urlString = self.url?.absoluteString {
			printableDescription += " " + urlString
		}
		if let headers = self.allHTTPHeaderFields, !headers.isEmpty {
			printableDescription += "\\nHeaders: \(headers)"
		}
		if let bodyData = self.httpBody,
			let body = String(data: bodyData, encoding: .utf8) {
			printableDescription += "\\nBody: \(body)"
		}
		
		return printableDescription.replacingOccurrences(of: "\\n", with: "\n")
	}
}

