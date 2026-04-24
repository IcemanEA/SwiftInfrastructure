//
//  DatabaseInfo.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 25.06.2025.
//

import Foundation

public struct DatabaseInfo {
	public let totalSizeBytes: Int
	public let usedSizeBytes: Int
	public let freeSizeBytes: Int
	public let pageCount: Int
	public let pageSize: Int
	public let tables: [TableInfo]

	public var totalSizeMB: Double {
		Double(totalSizeBytes) / (1024 * 1024)
	}

	public var usedSizeMB: Double {
		Double(usedSizeBytes) / (1024 * 1024)
	}
}
