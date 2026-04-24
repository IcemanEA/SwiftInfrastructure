//
//  MaskStringConvertible.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// A marker protocol that masks a conforming type's string representation to hide secret values in logs.
///
/// Conforming types inherit default implementations of `description` and
/// `debugDescription` that always return `"***********"`, preventing accidental
/// leakage of credentials when an instance is interpolated into a log line,
/// error message, or debugger output. Apply this to any type that wraps a
/// token, password, session identifier, or other secret.
public protocol MaskStringConvertible: CustomStringConvertible, CustomDebugStringConvertible { }

public extension MaskStringConvertible {
	var description: String {
		"***********"
	}

	var debugDescription: String {
		"***********"
	}
}
