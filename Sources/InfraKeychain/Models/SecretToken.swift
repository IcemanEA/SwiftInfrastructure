//
//  SecretToken.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 23.06.2025.
//

import Foundation
import InfraCore

/// A typed, log-masked wrapper around a secret string — the unit of transfer and storage used by ``IKeychainRepository``.
public struct SecretToken: MaskStringConvertible {
	/// The kind of secret this token represents.
	public let type: SecretTokenType

	/// The raw secret value.
	public let rawValue: String

	/// Creates a new secret token.
	///
	/// - Parameters:
	///   - type: The kind of secret.
	///   - rawValue: The secret value.
	public init(type: SecretTokenType, rawValue: String) {
		self.type = type
		self.rawValue = rawValue
	}
}
