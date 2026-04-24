//
//  NetworkError.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// Errors surfaced by the network layer.
///
/// ## Overview
///
/// Describes every failure mode that may arise during a network request. Cases
/// are grouped by category so call sites can treat connectivity, HTTP status,
/// auth, and decode problems differently.
public enum NetworkError: Error {

	// MARK: - Connectivity errors

	/// The device has no internet connection.
	case noNetworkConnection

	/// The server is unreachable or unresponsive.
	case noServerOnline

	/// A transport-layer error (time-out, SSL failure, etc.).
	case transportError(Error)

	// MARK: - Configuration errors

	/// The URL is malformed.
	case badURL

	// MARK: - Server-response errors

	/// The server's response has an unexpected shape.
	case invalidResponse(URLResponse?)

	/// The status code falls outside the success range `200..<300`.
	case invalidStatusCode(Int, Data?)

	/// The response body is empty where data was expected.
	case noData

	// MARK: - Authentication errors

	/// The session has expired.
	case sessionExpired

	/// The authentication token is invalid.
	case badToken

	// MARK: - Data-processing errors

	/// JSON decoding failed.
	case badDecode(Error)
}

// MARK: - Helper accessors

extension NetworkError {

	/// Whether the error is transient and retrying the operation may succeed.
	public var isRetryable: Bool {
		switch self {
		case .noNetworkConnection, .noServerOnline, .transportError:
			return true
		case .invalidStatusCode(let code, _):
			return code >= 500 || code == 408 || code == 429 // Server error, timeout, rate limit
		default:
			return false
		}
	}
	
	/// Whether the error signals that re-authentication is required.
	public var requiresReauth: Bool {
		switch self {
		case .sessionExpired, .badToken:
			return true
		case .invalidStatusCode(let code, _):
			return code == 401
		default:
			return false
		}
	}
	
	/// A short category label for analytics and grouping.
	public var category: String {
		switch self {
		case .noNetworkConnection, .transportError:
			return "connectivity"
		case .noServerOnline:
			return "server"
		case .badURL, .invalidResponse, .badDecode:
			return "client"
		case .invalidStatusCode:
			return "http"
		case .sessionExpired, .badToken:
			return "auth"
		case .noData:
			return "data"
		}
	}
}

// MARK: - CustomStringConvertible

extension NetworkError: CustomStringConvertible {
	public var description: String {
		switch self {
		case .noNetworkConnection:
			return "No internet connection"
			
		case .noServerOnline:
			return "Server is temporarily unavailable. Please try again later"
			
		case .badURL:
			return "Invalid web address"
			
		case .invalidResponse:
			return "Server returned an invalid response"
			
		case .invalidStatusCode(let code, _):
			if code >= 500 {
				return "Server error. Please try again later"
			} else if code == 404 {
				return "Requested resource not found"
			} else if code == 401 || code == 403 {
				return "Access denied. Please check your credentials"
			} else {
				return "Request failed with error code \(code)"
			}
			
		case .sessionExpired:
			return "Your session has expired. Please sign in again"
			
		case .badToken:
			return "Authentication error. Please sign in again"
			
		case .transportError:
			return "Network connection error"
			
		case .noData:
			return "No data available"
			
		case .badDecode:
			return "Data format error"
		}
	}
}
