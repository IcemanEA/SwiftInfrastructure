//
//  EmptyResponse.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 07.07.2025.
//

import Foundation

/// A placeholder response type used when the server returns `204 No Content` but the call site still needs a typed success value.
public struct EmptyResponse: Codable {
	public init() {}
}
