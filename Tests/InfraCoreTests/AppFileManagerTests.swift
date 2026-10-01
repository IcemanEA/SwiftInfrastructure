//
//  AppFileManagerTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import InfraCore
import InfraTestSupport

@Suite("AppFileManager")
struct AppFileManagerTests {

	private let sut = AppFileManager(logger: MockLogger())
	private let directory: URL

	init() throws {
		directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("InfraCoreTests", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func cleanUp() {
		try? FileManager.default.removeItem(at: directory)
	}

	private func writeFile(named name: String, contents: String) throws -> URL {
		let url = directory.appendingPathComponent(name)
		try Data(contents.utf8).write(to: url)
		return url
	}

	@Test("fileExists reflects the file system")
	func fileExists() throws {
		defer { cleanUp() }
		let url = try writeFile(named: "a.txt", contents: "a")

		#expect(sut.fileExists(atPath: url.path))
		#expect(sut.fileExists(atPath: directory.appendingPathComponent("missing").path) == false)
	}

	@Test("createDirectory creates intermediate directories")
	func createDirectory() throws {
		defer { cleanUp() }
		let nested = directory.appendingPathComponent("one/two/three").path

		try sut.createDirectory(atPath: nested, withIntermediateDirectories: true)

		#expect(sut.fileExists(atPath: nested))
	}

	@Test("moveItem moves a file to a free destination")
	func moveToFreeDestination() throws {
		defer { cleanUp() }
		let source = try writeFile(named: "source.txt", contents: "payload")
		let destination = directory.appendingPathComponent("destination.txt")

		try sut.moveItem(at: source, to: destination)

		#expect(sut.fileExists(atPath: source.path) == false)
		#expect(try String(contentsOf: destination, encoding: .utf8) == "payload")
	}

	@Test("moveItem replaces an existing destination")
	func moveReplacesExisting() throws {
		defer { cleanUp() }
		let source = try writeFile(named: "source.txt", contents: "new")
		let destination = try writeFile(named: "destination.txt", contents: "old")

		try sut.moveItem(at: source, to: destination)

		#expect(try String(contentsOf: destination, encoding: .utf8) == "new")
	}

	@Test("removeItem deletes the file and throws for a missing path")
	func removeItem() throws {
		defer { cleanUp() }
		let url = try writeFile(named: "a.txt", contents: "a")

		try sut.removeItem(atPath: url.path)

		#expect(sut.fileExists(atPath: url.path) == false)
		#expect(throws: (any Error).self) {
			try sut.removeItem(atPath: url.path)
		}
	}

	@Test("attributesOfItem reports the file size")
	func attributesReportSize() throws {
		defer { cleanUp() }
		let url = try writeFile(named: "a.txt", contents: "12345")

		let attributes = try sut.attributesOfItem(atPath: url.path)

		#expect((attributes[.size] as? NSNumber)?.intValue == 5)
	}

	@Test("urls(for:in:) resolves system directories")
	func systemDirectories() {
		defer { cleanUp() }

		#expect(!sut.urls(for: .cachesDirectory, in: .userDomainMask).isEmpty)
		#expect(!sut.urls(for: .documentDirectory, in: .userDomainMask).isEmpty)
	}
}
