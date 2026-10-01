//
//  ImageMetadataServiceTests.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import Testing
import UIKit
import InfraImageMetadata

@Suite("ImageMetadataService")
struct ImageMetadataServiceTests {

	private let directory: URL

	init() throws {
		directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("InfraImageMetadataTests", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func cleanUp() {
		try? FileManager.default.removeItem(at: directory)
	}

	/// Renders a solid image at scale 1 so its pixel size equals `size`, and writes it as PNG.
	private func writePNG(size: CGSize, named name: String) throws -> URL {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.systemTeal.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
		let url = directory.appendingPathComponent(name)
		try #require(image.pngData()).write(to: url)
		return url
	}

	// MARK: - getImageDimensions

	@Test("Reads pixel dimensions from a PNG on disk")
	func readsPNGDimensions() throws {
		defer { cleanUp() }
		let url = try writePNG(size: CGSize(width: 64, height: 32), named: "image.png")

		#expect(ImageMetadataService.getImageDimensions(from: url) == CGSize(width: 64, height: 32))
	}

	@Test("Returns nil for a missing file")
	func missingFile() {
		defer { cleanUp() }

		#expect(ImageMetadataService.getImageDimensions(from: directory.appendingPathComponent("missing.png")) == nil)
	}

	@Test("Returns nil for a file that is not an image")
	func notAnImage() throws {
		defer { cleanUp() }
		let url = directory.appendingPathComponent("notes.txt")
		try Data("plain text".utf8).write(to: url)

		#expect(ImageMetadataService.getImageDimensions(from: url) == nil)
	}

	// MARK: - calculateHeight

	@Test("Preserves the aspect ratio at the target width", arguments: [
		(CGSize(width: 200, height: 100), CGFloat(300), CGFloat(150)),
		(CGSize(width: 100, height: 200), CGFloat(300), CGFloat(600)),
		(CGSize(width: 50, height: 50), CGFloat(300), CGFloat(300))
	])
	func calculateHeight(original: CGSize, targetWidth: CGFloat, expected: CGFloat) {
		#expect(ImageMetadataService.calculateHeight(for: original, targetWidth: targetWidth) == expected)
	}
}
