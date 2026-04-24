//
//  LogLevel.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import os.log

/// Severity levels for log messages, ordered by increasing criticality.
///
/// ## Overview
///
/// Each level represents a certain degree of event severity. Levels are used to
/// filter logs and decide how they are presented. When a minimum log level is
/// configured, only events at that level or higher are recorded.
///
/// ## Hierarchy (least to most severe)
///
/// 1. `verbose` — maximum-detail diagnostic information.
/// 2. `debug` — debug information for developers.
/// 3. `info` — general information about normal operation.
/// 4. `warning` — warnings about potential problems.
/// 5. `error` — errors that do not abort execution.
/// 6. `critical` — critical errors that require immediate attention.
///
/// ```swift
/// let logger = Logger(minimumLogLevel: .warning, /* ... */)
/// // Only warning, error, and critical messages will be recorded.
/// ```
public enum LogLevel: String, CaseIterable {
	/// Maximum-detail information for deep debugging.
	///
	/// Use to record detailed execution traces, variable values, intermediate
	/// states, and other fine-grained information useful when investigating
	/// complex problems.
	case verbose = "VERBOSE"

	/// Debug information for developers.
	///
	/// Use for information helpful during development: method-call traces,
	/// object state, and details of program logic.
	case debug = "DEBUG"

	/// General information about normal application operation.
	///
	/// Records significant life-cycle events, successful operations, and the
	/// reaching of key milestones. Suitable for production-level monitoring.
	case info = "INFO"

	/// Warnings about potential problems.
	///
	/// Indicates situations that may cause trouble but do not interrupt the
	/// current flow — for example, deprecated APIs, slow operations, or
	/// sub-optimal configurations.
	case warning = "WARNING"

	/// Errors that do not abort application execution.
	///
	/// Records errors that can be handled and recovered from. The application
	/// keeps running, though some functionality may be degraded or misbehave.
	case error = "ERROR"

	/// Critical errors that require immediate attention.
	///
	/// Indicates serious problems that may lead to application crash, data
	/// loss, or major functional failure. Requires urgent intervention.
	case critical = "CRITICAL"

	/// An emoji representation of the level for visual distinction in log output.
	var emoji: String {
		switch self {
		case .verbose: return "💬"
		case .debug: return "🐛"
		case .info: return "ℹ️"
		case .warning: return "⚠️"
		case .error: return "❌"
		case .critical: return "💥"
		}
	}

	/// The matching `OSLogType` used to integrate with Apple's unified logging system.
	var osLogType: OSLogType {
		switch self {
		case .verbose, .debug: return .debug
		case .info: return .info
		case .warning: return .default
		case .error: return .error
		case .critical: return .fault
		}
	}
}
