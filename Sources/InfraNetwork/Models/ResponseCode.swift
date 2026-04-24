//
//  ResponseCode.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation

public enum ResponseCode {
	static let informationalCodes = 100..<200
	static let successCodes = 200..<300
	static let redirectCodes = 300..<400
	static let clientErrorCodes = 400..<500
	static let serverErrorCodes = 500..<600
}
