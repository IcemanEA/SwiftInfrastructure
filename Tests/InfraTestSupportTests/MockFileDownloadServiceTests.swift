//
//  MockFileDownloadServiceTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraFileCache
import InfraTestSupport

@Suite("MockFileDownloadService")
struct MockFileDownloadServiceTests {

	private let directory: URL
	private let remoteURL = URL(string: "https://example.com/files/report.pdf")!

	init() throws {
		directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("InfraTestSupportTests", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func makeService(totalDownloadTime: TimeInterval = 0.05) -> MockFileDownloadService {
		var configuration = MockFileDownloadService.Configuration()
		configuration.progressUpdateInterval = 0.01
		configuration.totalDownloadTime = totalDownloadTime
		return MockFileDownloadService(configuration: configuration)
	}

	private func cleanUp() {
		try? FileManager.default.removeItem(at: directory)
	}

	@available(iOS 16, *)
	@Test("A successful download returns the local path and creates the file", .timeLimit(.minutes(1)))
	func successfulDownload() async throws {
		defer { cleanUp() }
		let sut = makeService()
		let localPath = directory.appendingPathComponent("report.pdf").path

		let result = await sut.downloadFile(from: remoteURL, to: localPath, progressHandler: nil)

		let url = try result.get()
		#expect(url.path == localPath)
		#expect(FileManager.default.fileExists(atPath: localPath))
	}

	@available(iOS 16, *)
	@Test("Progress values stay within 0...1 and end at 1.0", .timeLimit(.minutes(1)))
	func progressRange() async throws {
		defer { cleanUp() }
		let sut = makeService()
		let localPath = directory.appendingPathComponent("report.pdf").path
		let recorder = ProgressRecorder()

		_ = await sut.downloadFile(from: remoteURL, to: localPath, progressHandler: { recorder.append($0) })

		let values = recorder.values
		try #require(!values.isEmpty, "The mock must report progress at least once")
		#expect(values.allSatisfy { (0.0...1.0).contains($0) })
		#expect(values.last == 1.0)
	}

	@available(iOS 16, *)
	@Test("A second download of the same pair while the first is in progress is rejected", .timeLimit(.minutes(1)))
	func duplicateDownloadRejected() async throws {
		defer { cleanUp() }
		let sut = makeService(totalDownloadTime: 0.5)
		let localPath = directory.appendingPathComponent("report.pdf").path
		let url = remoteURL

		let first = Task { await sut.downloadFile(from: url, to: localPath, progressHandler: nil) }
		while await sut.getDownloadProgress(url: url, localPath: localPath) == nil {
			try await Task.sleep(nanoseconds: 5_000_000)
		}

		let second = await sut.downloadFile(from: url, to: localPath, progressHandler: nil)

		guard case .failure(.downloadInProgress) = second else {
			Issue.record("Expected .downloadInProgress, got \(second)")
			return
		}
		let firstResult = await first.value
		#expect((try? firstResult.get()) != nil)
	}

	@available(iOS 16, *)
	@Test("Cancelling an unknown task returns taskNotFound", .timeLimit(.minutes(1)))
	func cancelUnknownTask() async {
		defer { cleanUp() }
		let sut = makeService()

		let result = await sut.cancelDownload(url: remoteURL, localPath: directory.appendingPathComponent("x").path)

		guard case .failure(.taskNotFound) = result else {
			Issue.record("Expected .taskNotFound, got \(result)")
			return
		}
	}
}

/// Collects progress callbacks from the mock, which may arrive on any thread.
private final class ProgressRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var storage: [Double] = []

	var values: [Double] {
		lock.lock()
		defer { lock.unlock() }
		return storage
	}

	func append(_ value: Double) {
		lock.lock()
		defer { lock.unlock() }
		storage.append(value)
	}
}
