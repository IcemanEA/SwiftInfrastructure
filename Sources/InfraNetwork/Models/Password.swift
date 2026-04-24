//
//  Password.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraCore

/// A user password. The underlying value is masked in log output via ``MaskStringConvertible``.
public struct Password: MaskStringConvertible {
	/// The raw password string.
	let rawValue: String
}
