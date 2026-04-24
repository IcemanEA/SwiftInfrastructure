//
//  CertificateGeneratorFactory.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on [DATE].
//

import Foundation

/// A factory that dispatches to the appropriate ``IPdfCertificateGenerator`` based on the template's file extension.
public final class CertificateGeneratorFactory {

	private let imageGenerator: IPdfCertificateGenerator
	private let pdfGenerator: IPdfCertificateGenerator

	public init(
		imageGenerator: IPdfCertificateGenerator,
		pdfGenerator: IPdfCertificateGenerator
	) {
		self.imageGenerator = imageGenerator
		self.pdfGenerator = pdfGenerator
	}

	/// Returns the generator that can handle the given template URL, based on its file extension.
	public func getGenerator(for templateUrl: URL) -> IPdfCertificateGenerator {
		let templateType = CertificateTemplateType.from(url: templateUrl)

		switch templateType {
		case .image:
			return imageGenerator
		case .pdf:
			return pdfGenerator
		}
	}
}
