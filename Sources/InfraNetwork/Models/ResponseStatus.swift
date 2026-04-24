//
//  ResponseStatus.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// HTTP response status buckets, each carrying the numeric status code.
public enum ResponseStatus {
	/// Informational response — `1xx`.
	case information(Int)
	/// Successful response — `2xx`.
	case success(Int)
	/// Redirection response — `3xx`.
	case redirect(Int)
	/// Client error — `4xx`.
	case clientError(Int)
	/// Server error — `5xx`.
	case serverError(Int)

	public init?(rawValue: Int) {
		if ResponseCode.informationalCodes.contains(rawValue) {
			self = .information(rawValue)
		} else if ResponseCode.successCodes.contains(rawValue) {
			self = .success(rawValue)
		} else if ResponseCode.redirectCodes.contains(rawValue) {
			self = .redirect(rawValue)
		} else if ResponseCode.clientErrorCodes.contains(rawValue) {
			self = .clientError(rawValue)
		} else if ResponseCode.serverErrorCodes.contains(rawValue) {
			self = .serverError(rawValue)
		} else {
			return nil
		}
	}

	/// Returns `true` when the status falls in the `2xx` success range.
	public var isSuccess: Bool {
		switch self {
		case .success:
			return true
		default:
			return false
		}
	}
}
