//
//  LogCategory.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

/// Logical groupings of log events by functional area.
///
/// ## Overview
///
/// Categories let you organize logs by meaning, which simplifies filtering,
/// searching, and analysing them. A `LogCategory` is purely a logical label;
/// the per-app `OSLog` subsystem identity is owned by ``Logger`` via its
/// `subsystemPrefix` init parameter, not by this type.
///
/// Use categories to:
/// - Group events by the code area they originate from.
/// - Simplify filtering logs during debugging.
/// - Allow different minimum log levels per component (via the logger).
/// - Integrate with Console.app and Instruments for performance analysis.
///
/// ```swift
/// let networkLogger = LogManager(logger: logger, category: .network)
/// let databaseLogger = LogManager(logger: logger, category: .database)
/// let filesLogger = LogManager(logger: logger, category: .files)
///
/// networkLogger.info("API call started")
/// databaseLogger.error("Database connection failed")
/// filesLogger.info("File download completed")
/// ```
public enum LogCategory: String, CaseIterable, Sendable {
	/// Network operations and API interaction.
	///
	/// Use for:
	/// - HTTP/HTTPS requests and responses.
	/// - WebSocket connections.
	/// - Network errors and time-outs.
	/// - Network-performance metrics.
	case network = "NETWORK"

	/// Database operations and local storage.
	///
	/// Use for:
	/// - CRUD operations against the database.
	/// - Schema migrations.
	/// - Core Data or SQLite interactions.
	/// - UserDefaults and Keychain work.
	/// - Data synchronization.
	case database = "DATABASE"

	/// File operations and the file cache.
	///
	/// Use for:
	/// - Uploading and downloading files.
	/// - File-cache operations.
	/// - Local file-system access.
	/// - File-storage management.
	/// - File-operation errors.
	case files = "FILES"

	/// User-interface events and interaction.
	///
	/// Use for:
	/// - Navigation between screens.
	/// - User actions (taps, swipes).
	/// - View-controller life-cycle events.
	/// - Animations and transitions.
	/// - UI rendering errors.
	case ui = "UI"

	/// Business logic and domain operations.
	///
	/// Use for:
	/// - Execution of business rules.
	/// - Data validation.
	/// - Calculations and algorithms.
	/// - Workflows and processes.
	/// - Domain events.
	case business = "BUSINESS"

	/// Security and authentication events.
	///
	/// Use for:
	/// - Sign-in and sign-out attempts.
	/// - Authentication errors.
	/// - Token and certificate operations.
	/// - Suspicious activity.
	/// - Security-policy violations.
	case repository = "REPO"

	/// Performance metrics and optimisation.
	///
	/// Use for:
	/// - Operation timing.
	/// - Memory and CPU usage.
	/// - Algorithm performance.
	/// - Code hot spots.
	/// - Application profiling.
	case performance = "PERFORMANCE"

	/// Component and application life cycle.
	///
	/// Use for:
	/// - Application start-up and termination.
	/// - Object creation and disposal.
	/// - State transitions.
	/// - Component initialization.
	/// - iOS life-cycle events.
	case lifecycle = "LIFECYCLE"

	/// General events that don't fit other categories.
	///
	/// Use for:
	/// - Generic informational messages.
	/// - Events without a specific category.
	/// - Temporary logs used during development.
	/// - Miscellaneous application events.
	case general = "GENERAL"
}
