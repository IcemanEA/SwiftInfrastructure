//
//  ILogger.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

/// A protocol for emitting log messages at various severity levels.
///
/// ## Overview
///
/// `ILogger` is the low-level logging sink of the package. It provides a unified
/// interface for recording events with a severity level and a logical category,
/// and it automatically captures call-site metadata (file, function, line) to
/// simplify debugging. Services that log do not usually take an `ILogger` directly —
/// they wrap one in a ``LogManager`` bound to a single ``LogCategory`` and call the
/// category-less proxy methods.
///
/// ```swift
/// final class NetworkManager {
///     private let logger: ILogger
///
///     init(logger: ILogger) {
///         self.logger = logger
///     }
///
///     func fetchData() {
///         logger.info("Starting data fetch", category: .network)
///         // ... logic
///         logger.error("Fetch failed", category: .network)
///     }
/// }
/// ```
///
/// ## Levels
///
/// - `verbose` — fine-grained debug detail.
/// - `debug` — debug information for developers.
/// - `info` — general information about application behaviour.
/// - `warning` — warnings about potential problems.
/// - `error` — errors that do not abort execution.
/// - `critical` — critical errors that require immediate attention.
///
/// ## Categories
///
/// - `network` — network operations.
/// - `database` — database operations.
/// - `ui` — user-interface events.
/// - `business` — business logic.
/// - `repository` — events from composed repositories.
/// - `performance` — performance metrics.
/// - `lifecycle` — component life cycle.
/// - `general` — events without a more specific category.
public protocol ILogger: Sendable {

	/// The primary logging entry point with full parameter control.
	///
	/// - Parameters:
	///   - level: The severity level of the message.
	///   - message: The message text to log.
	///   - category: The event category used to group logs.
	///   - file: The file from which the log call originates (captured automatically).
	///   - function: The function from which the log call originates (captured automatically).
	///   - line: The source line of the call site (captured automatically).
	func log(_ level: LogLevel, _ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs fine-grained debug information.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func verbose(_ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs debug information intended for developers.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs general information about application behaviour.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func info(_ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs warnings about potential problems.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs errors that do not abort application execution.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func error(_ message: String, category: LogCategory, file: String, function: String, line: Int)

	/// Logs critical errors that require immediate attention.
	///
	/// - Parameters:
	///   - message: The message text.
	///   - category: The event category (defaults to `.general` at the implementation level).
	///   - file: The call-site file (captured automatically).
	///   - function: The call-site function (captured automatically).
	///   - line: The call-site line (captured automatically).
	func critical(_ message: String, category: LogCategory, file: String, function: String, line: Int)
}
