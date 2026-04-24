//
//  Parameters.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 25.06.2025.
//

import Foundation

/// Request parameters — either absent, or carried in the URL as query items.
public enum Parameters {
	/// No parameters.
	case none
	/// Parameters appended to the URL as query items; typically used with `GET`. Supplied as a dictionary.
	case url([String: Any])
}
