//
//  TestRequest.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 01.10.2026.
//

import Foundation
import InfraNetwork

/// An `INetworkRequest` value with every field settable, including `header`, which `NetworkRequest` does not expose.
struct TestRequest: INetworkRequest {
	var method: HTTPMethod = .get
	var path: String
	var header: HTTPHeader?
	var parameters: Parameters?
	var body: HTTPBody?
}
