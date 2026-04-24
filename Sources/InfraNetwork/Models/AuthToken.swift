//
//  AuthToken.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraCore

/// An authorization bearer token. The underlying value is masked in log output via ``MaskStringConvertible``.
public struct AuthToken: MaskStringConvertible {
	/// The raw token string.
	let rawValue: String

	public init(rawValue: String) {
		self.rawValue = rawValue
	}
}
