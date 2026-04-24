//
//  IAppFileManager.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 03.07.2025.
//

import Foundation

/// An application-level file manager.
///
/// A thin wrapper over `FileManager` that exposes the subset of file-system
/// operations commonly needed inside an app: existence checks, directory
/// creation, moves, removals, attribute reads, system-directory lookup, and
/// a bulk cache-clear helper.
public protocol IAppFileManager {

	/// Returns whether a file exists at the given path.
	func fileExists(atPath path: String) -> Bool

	/// Creates a directory at the given path, creating intermediate directories when requested.
	func createDirectory(atPath path: String, withIntermediateDirectories: Bool) throws

	/// Moves an item from one URL to another.
	func moveItem(at srcURL: URL, to dstURL: URL) throws

	/// Removes the item at the given path.
	func removeItem(atPath path: String) throws

	/// Returns the attributes of the item at the given path.
	func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]

	/// Returns URLs for a system directory in the given search-path domain.
	///
	/// - Parameters:
	///   - directory: The kind of system directory being requested.
	///   - domainMask: The search-path domain (typically `.userDomainMask`).
	/// - Returns: Matching directory URLs, or an empty array if none are found.
	func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]

	/// Clears every cached file produced by the application.
	///
	/// Removes the contents of the following locations:
	/// - The Caches directory (including `URLCache`).
	/// - The temporary directory.
	/// - Any Application Support cache subdirectories.
	///
	/// > Warning: This method deletes all cached data produced by the app. Use
	/// > only for a full reset during debugging.
	///
	/// - Returns: `true` if the clearing succeeded, `false` on error.
	func clearAllCaches() -> Bool
}
