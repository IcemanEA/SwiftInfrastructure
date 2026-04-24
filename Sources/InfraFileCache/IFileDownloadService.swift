//
//  IFileDownloadService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.07.2025.
//

import Foundation

/// A service for downloading files from remote URLs into the local file system with progress, pause, resume, and cancel.
///
/// ## Overview
///
/// Implementations manage downloads from remote servers into the local file
/// system and surface progress to the caller via a closure. Every method is
/// thread-safe. Errors are reported through ``FileDownloadError``.
public protocol IFileDownloadService {

	// MARK: - Core operations

	/// Downloads a file from a remote URL to the local file system.
	///
	/// - Parameters:
	///   - url: The remote URL to download from.
	///   - localPath: The local file-system path where the downloaded file should be saved.
	///   - progressHandler: A closure that receives progress values in the range `0.0 ... 1.0`. Optional.
	/// - Returns: A `Result` containing the local URL of the downloaded file, or a ``FileDownloadError`` on failure.
	func downloadFile(
		from url: URL,
		to localPath: String,
		progressHandler: ((Double) -> Void)?
	) async -> Result<URL, FileDownloadError>

	// MARK: - Download control

	/// Pauses an in-flight download.
	///
	/// - Parameters:
	///   - url: The remote URL of the download to pause.
	///   - localPath: The local path associated with the download.
	/// - Returns: `.success(())` on success, or a ``FileDownloadError`` on failure.
	func pauseDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError>

	/// Resumes a paused download.
	///
	/// - Parameters:
	///   - url: The remote URL of the download to resume.
	///   - localPath: The local path associated with the download.
	/// - Returns: A `Result` containing the local URL of the downloaded file, or a ``FileDownloadError`` on failure.
	func resumeDownload(url: URL, localPath: String) async -> Result<URL, FileDownloadError>

	/// Cancels an in-flight download.
	///
	/// - Parameters:
	///   - url: The remote URL of the download to cancel.
	///   - localPath: The local path associated with the download.
	/// - Returns: `.success(())` on success, or a ``FileDownloadError`` on failure.
	func cancelDownload(url: URL, localPath: String) async -> Result<Void, FileDownloadError>

	// MARK: - Monitoring

	/// Returns the current progress of an in-flight download.
	///
	/// - Parameters:
	///   - url: The remote URL of the download.
	///   - localPath: The local path associated with the download.
	/// - Returns: A value in the range `0.0 ... 1.0`, or `nil` if the download is not found.
	func getDownloadProgress(url: URL, localPath: String) async -> Double?
}
