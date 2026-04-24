//
//  FileDownloadError.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.07.2025.
//

import Foundation

/// The failure modes of ``IFileDownloadService``.
///
/// ## Overview
///
/// Enumerates every error a file-download service can surface. Each case
/// carries a human-readable description via ``CustomStringConvertible``.
public enum FileDownloadError: Error {

	// MARK: - System errors

	/// An internal error in the download service.
	case internalError

	/// A file-system error occurred while handling local files.
	case fileSystemError(Error)

	// MARK: - Download-state errors

	/// A download for this resource is already in progress.
	case downloadInProgress

	/// The referenced download task could not be found (already finished, or never existed).
	case taskNotFound

	/// No resume data is available for the paused download.
	case noResumeData

	// MARK: - Download errors

	/// The temporary file produced by the download could not be located after completion.
	case noTempFile

	/// The URL is invalid or unreachable.
	case invalidUrl

	/// The download exceeded its time-out.
	case timeout

	/// Not enough disk space to store the downloaded file.
	case insufficientStorage

	// MARK: - Network errors

	/// The device has no internet connection.
	case noInternetConnection

	/// The server was unreachable or returned an error status code.
	case serverError(statusCode: Int)

	// MARK: - User Messages (Localized)
}

// MARK: - CustomStringConvertible

extension FileDownloadError: CustomStringConvertible {
	public var description: String {
		switch self {
		case .internalError:
			return "Internal download service error"
		case .fileSystemError:
			return "File system error occurred"
		case .downloadInProgress:
			return "Download is already in progress"
		case .taskNotFound:
			return "Download task not found"
		case .noResumeData:
			return "Cannot resume download"
		case .noTempFile:
			return "Downloaded file is not available"
		case .invalidUrl:
			return "Invalid download URL"
		case .timeout:
			return "Download timeout exceeded"
		case .insufficientStorage:
			return "Not enough storage space"
		case .noInternetConnection:
			return "No internet connection"
		case .serverError(let statusCode):
			if statusCode >= 500 {
				return "Server error. Please try again later"
			} else if statusCode == 404 {
				return "File not found on server"
			} else if statusCode == 401 || statusCode == 403 {
				return "Access denied to download file"
			} else {
				return "Download failed with error code \(statusCode)"
			}
		}
	}
}

// MARK: - Equatable Implementation

extension FileDownloadError: Equatable {
	public static func == (lhs: FileDownloadError, rhs: FileDownloadError) -> Bool {
		switch (lhs, rhs) {
		case (.internalError, .internalError),
			 (.downloadInProgress, .downloadInProgress),
			 (.taskNotFound, .taskNotFound),
			 (.noResumeData, .noResumeData),
			 (.noTempFile, .noTempFile),
			 (.invalidUrl, .invalidUrl),
			 (.timeout, .timeout),
			 (.insufficientStorage, .insufficientStorage),
			 (.noInternetConnection, .noInternetConnection):
			return true
		case (.fileSystemError(let lhsError), .fileSystemError(let rhsError)):
			return lhsError.localizedDescription == rhsError.localizedDescription
		case (.serverError(let lhsCode), .serverError(let rhsCode)):
			return lhsCode == rhsCode
		default:
			return false
		}
	}
}
