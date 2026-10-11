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
public final class MockPdfCertificateGenerator: IPdfCertificateGenerator, Sendable {

	private struct State {
		var result: (previewData: Data, pdfData: Data) = (Data(), Data())
		var error: Error?
		var paths: [String] = []
	}

	private let state = LockedState(State())

	public init() {}

	/// The value returned by ``generateCertificate(templateImagePath:certificateData:)`` when no error is configured.
	public var result: (previewData: Data, pdfData: Data) {
		get { state.withLock { $0.result } }
		set { state.withLock { $0.result = newValue } }
	}

	/// The error thrown by ``generateCertificate(templateImagePath:certificateData:)``; `nil` means succeed.
	public var errorToThrow: Error? {
		get { state.withLock { $0.error } }
		set { state.withLock { $0.error = newValue } }
	}

	/// The template paths passed to every call, in call order.
	public var recordedTemplatePaths: [String] {
		state.withLock { $0.paths }
	}

	public func generateCertificate(
		templateImagePath: String,
		certificateData: CertificateData
	) async throws -> (previewData: Data, pdfData: Data) {
		let (result, error) = state.withLock { state in
			state.paths.append(templateImagePath)
			return (state.result, state.error)
		}

		if let error {
			throw error
		}
		return result
	}
}
