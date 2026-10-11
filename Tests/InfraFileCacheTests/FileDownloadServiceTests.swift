//
//  FileDownloadServiceTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 11.10.2026.
//

import Foundation
import Testing
import InfraCore
import InfraFileCache
import InfraTestSupport

@Suite("FileDownloadService")
struct FileDownloadServiceTests {

	/// A temporary directory owned by one test.
	private struct Sandbox {
		let directory: URL

		init() throws {
			directory = FileManager.default.temporaryDirectory
				.appendingPathComponent("InfraFileCacheTests.\(UUID().uuidString)", isDirectory: true)
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		}

		func path(_ name: String) -> String {
			directory.appendingPathComponent(name).path
		}

		func cleanUp() {
			try? FileManager.default.removeItem(at: directory)
		}
	}

	private func makeSut() -> FileDownloadService {
		let logger = MockLogger()
		return FileDownloadService(
			logger: logger,
			appFileManager: AppFileManager(logger: logger),
			sessionConfiguration: StubDownloadProtocol.makeConfiguration()
		)
	}

	/// Registers a reply under a unique path and returns the URL that requests it.
	private func stub(_ reply: StubDownloadProtocol.Reply) -> URL {
		let path = "/files/\(UUID().uuidString)"
		StubDownloadProtocol.register(path: path, reply: reply)
		return URL(string: "https://downloads.example.com\(path)")!
	}

	/// The error of a `Result<Void, _>`, which is not `Equatable` itself.
	private func error(of result: Result<Void, FileDownloadError>) -> FileDownloadError? {
		if case .failure(let error) = result { error } else { nil }
	}

	private func sleep(_ seconds: Double) async {
		try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
	}

	// MARK: - Downloading

	@Test("Concurrent downloads of different files each complete with their own body")
	func concurrentDownloads() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let firstUrl = stub(.init(body: Data("first".utf8), delay: 0.2))
		let secondUrl = stub(.init(body: Data("second".utf8), delay: 0.2))
		defer {
			StubDownloadProtocol.unregister(path: firstUrl.path)
			StubDownloadProtocol.unregister(path: secondUrl.path)
		}

		async let first = sut.downloadFile(from: firstUrl, to: sandbox.path("first.txt"), progressHandler: nil)
		async let second = sut.downloadFile(from: secondUrl, to: sandbox.path("second.txt"), progressHandler: nil)
		let results = await (first, second)

		let firstFile = try results.0.get()
		let secondFile = try results.1.get()
		#expect(try Data(contentsOf: firstFile) == Data("first".utf8))
		#expect(try Data(contentsOf: secondFile) == Data("second".utf8))
	}

	@Test("A second download of the same pair is rejected while the first is in progress")
	func duplicateRejected() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let url = stub(.init(body: Data("body".utf8), delay: 0.5))
		defer { StubDownloadProtocol.unregister(path: url.path) }
		let localPath = sandbox.path("file.txt")

		let first = Task { await sut.downloadFile(from: url, to: localPath, progressHandler: nil) }
		await sleep(0.1)
		let second = await sut.downloadFile(from: url, to: localPath, progressHandler: nil)

		#expect(second == .failure(.downloadInProgress))
		#expect(await first.value == .success(URL(fileURLWithPath: localPath)))
	}

	@Test("Progress values stay within 0...1 and the download completes")
	func progressIsReported() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let body = Data(repeating: 7, count: 64 * 1024)
		let url = stub(.init(body: body, chunks: 8))
		defer { StubDownloadProtocol.unregister(path: url.path) }
		let reported = LockedState<[Double]>([])

		let result = await sut.downloadFile(from: url, to: sandbox.path("big.bin"), progressHandler: { value in
			reported.withLock { $0.append(value) }
		})

		let file = try result.get()
		#expect(try Data(contentsOf: file) == body)
		let values = reported.withLock { $0 }
		#expect(values.allSatisfy { (0.0...1.0).contains($0) })
	}

	@Test("An HTTP error status is reported with its code and no file is kept")
	func httpErrorStatus() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let url = stub(.init(statusCode: 404, body: Data("missing".utf8)))
		defer { StubDownloadProtocol.unregister(path: url.path) }
		let localPath = sandbox.path("missing.txt")

		let result = await sut.downloadFile(from: url, to: localPath, progressHandler: nil)

		#expect(result == .failure(.serverError(statusCode: 404)))
		#expect(!FileManager.default.fileExists(atPath: localPath))
	}

	// MARK: - Control

	@Test("Cancelling completes the waiting caller and forgets the download")
	func cancelCompletesWaiter() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let url = stub(.init(body: Data("body".utf8), delay: 2))
		defer { StubDownloadProtocol.unregister(path: url.path) }
		let localPath = sandbox.path("file.txt")

		let start = Date()
		let download = Task { await sut.downloadFile(from: url, to: localPath, progressHandler: nil) }
		await sleep(0.1)
		let cancel = await sut.cancelDownload(url: url, localPath: localPath)

		#expect(error(of: cancel) == nil)
		#expect(await download.value == .failure(.internalError))
		#expect(Date().timeIntervalSince(start) < 1.5)
		#expect(await sut.getDownloadProgress(url: url, localPath: localPath) == nil)
	}

	@Test("Pausing keeps the caller waiting and resuming completes both callers")
	func pauseAndResume() async throws {
		let sandbox = try Sandbox()
		defer { sandbox.cleanUp() }
		let sut = makeSut()
		let url = stub(.init(body: Data("body".utf8), delay: 0.5))
		defer { StubDownloadProtocol.unregister(path: url.path) }
		let localPath = sandbox.path("file.txt")
		let expected = URL(fileURLWithPath: localPath)

		let download = Task { await sut.downloadFile(from: url, to: localPath, progressHandler: nil) }
		await sleep(0.1)
		let pause = await sut.pauseDownload(url: url, localPath: localPath)
		#expect(error(of: pause) == nil)

		let resumed = await sut.resumeDownload(url: url, localPath: localPath)

		#expect(resumed == .success(expected))
		#expect(await download.value == .success(expected))
		#expect(try Data(contentsOf: expected) == Data("body".utf8))
		#expect(StubDownloadProtocol.requestCount(path: url.path) == 2)
	}

	@Test("Control calls for an unknown download report it as missing")
	func unknownDownload() async {
		let sut = makeSut()
		let url = URL(string: "https://downloads.example.com/unknown")!

		#expect(error(of: await sut.pauseDownload(url: url, localPath: "/tmp/x")) == .taskNotFound)
		#expect(error(of: await sut.cancelDownload(url: url, localPath: "/tmp/x")) == .taskNotFound)
		#expect(await sut.resumeDownload(url: url, localPath: "/tmp/x") == .failure(.noResumeData))
		#expect(await sut.getDownloadProgress(url: url, localPath: "/tmp/x") == nil)
	}
}
