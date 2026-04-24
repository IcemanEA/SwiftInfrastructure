//
//  ResponseHealth.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

/// The result of a server health-check probe.
public struct ResponseHealth: Decodable {
	/// Whether the server is reachable and responding.
	public let isOnline: Bool

	public init(isOnline: Bool) {
		self.isOnline = isOnline
	}
}
