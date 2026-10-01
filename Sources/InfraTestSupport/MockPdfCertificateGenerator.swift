//
//  MockPdfCertificateGenerator.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import InfraPdf

/// A configurable ``IPdfCertificateGenerator`` for tests.
///
/// ## Overview
///
/// Returns ``result`` from every call, or throws ``errorToThrow`` when it is
/// set, and records the template paths it was called with. No rendering takes
/// place.
///
/// ```swift
/// let generator = MockPdfCertificateGenerator()
/// generator.result = (previewData: Data([1]), pdfData: Data([2]))
/// let output = try await generator.generateCertificate(templateImagePath: "t.png", certificateData: data)
/// #expect(generator.recordedTemplatePaths == ["t.png"])
/// ```
public final class MockPdfCertificateGenerator: IPdfCertificateGenerator, @unchecked Sendable {

	private let lock = NSLock()
	private var storedResult: (previewData: Data, pdfData: Data) = (Data(), Data())
	private var storedError: Error?
	private var storedPaths: [String] = []

	public init() {}

	/// The value returned by ``generateCertificate(templateImagePath:certificateData:)`` when no error is configured.
	public var result: (previewData: Data, pdfData: Data) {
		get { lock.lock(); defer { lock.unlock() }; return storedResult }
		set { lock.lock(); defer { lock.unlock() }; storedResult = newValue }
	}

	/// The error thrown by ``generateCertificate(templateImagePath:certificateData:)``; `nil` means succeed.
	public var errorToThrow: Error? {
		get { lock.lock(); defer { lock.unlock() }; return storedError }
		set { lock.lock(); defer { lock.unlock() }; storedError = newValue }
	}

	/// The template paths passed to every call, in call order.
	public var recordedTemplatePaths: [String] {
		lock.lock()
		defer { lock.unlock() }
		return storedPaths
	}

	public func generateCertificate(
		templateImagePath: String,
		certificateData: CertificateData
	) async throws -> (previewData: Data, pdfData: Data) {
		let (result, error): ((Data, Data), Error?) = {
			lock.lock()
			defer { lock.unlock() }
			storedPaths.append(templateImagePath)
			return (storedResult, storedError)
		}()

		if let error {
			throw error
		}
		return (previewData: result.0, pdfData: result.1)
	}
}
