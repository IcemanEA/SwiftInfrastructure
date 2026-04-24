//
//  DatabaseError.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 25.06.2025.
//

import Foundation
import GRDB

/// Data-access-layer errors.
///
/// ## Overview
///
/// Enumerates every failure mode that may surface when working with the
/// database through GRDB. Cases are grouped by category of problem to make
/// handling — and any user-facing messages — more precise.
public enum DatabaseError: Error {

	// MARK: - Data errors

	/// No record matched the given criteria.
	case recordNotFound

	/// The database contents are corrupted or in an unexpected format.
	case corruptedData

	/// Data validation failed before the write.
	case validationFailed(String)

	/// An integrity constraint was violated (foreign key, unique, etc.).
	case constraintViolation(String)

	// MARK: - Transaction and concurrency errors

	/// The database is locked by another process (`SQLITE_BUSY`).
	case databaseBusy

	/// The operation was interrupted (`SQLITE_INTERRUPT`).
	case operationInterrupted

	/// The operation was aborted (`SQLITE_ABORT`).
	case operationAborted

	/// A transaction was rolled back due to an error.
	case transactionRolledBack(String)

	/// A transaction was left uncommitted.
	case uncommittedTransaction

	// MARK: - Migration and schema errors

	/// A database migration failed to apply.
	case migrationFailed(String)

	/// The on-disk schema version differs from the expected version.
	case schemaVersionMismatch(expected: Int, actual: Int)

	/// An error occurred while creating or altering the schema.
	case schemaError(String)

	// MARK: - File-system and resource errors

	/// Insufficient disk space.
	case diskFull

	/// The database file was not found.
	case databaseFileNotFound

	/// Access to the database file was denied.
	case permissionDenied

	/// An I/O error occurred while working with the database file.
	case ioError(String)

	// MARK: - Configuration and connection errors

	/// Database initialization failed.
	case initializationFailed(String)

	/// The database configuration is invalid.
	case configurationError(String)

	/// A connection attempt timed out.
	case connectionTimeout

	// MARK: - Query and SQL errors

	/// A SQL statement contained a syntax error.
	case sqlSyntaxError(String)

	/// A SQL statement failed to compile.
	case sqlCompilationError(String)

	/// A referenced table or column does not exist.
	case unknownTableOrColumn(String)

	/// A query failed during execution.
	case queryExecutionFailed(String)

	// MARK: - Encoding and decoding errors

	/// Decoding values read from the database failed.
	case decodingFailed(String)

	/// Encoding values for storage in the database failed.
	case encodingFailed(String)

	/// The value uses a data type that is not supported.
	case unsupportedDataType(String)

	// MARK: - Observation errors (ValueObservation)

	/// Setting up a `ValueObservation` failed.
	case observationSetupFailed(String)

	/// A `ValueObservation` failed while running.
	case observationFailed(String)

	// MARK: - Critical errors

	/// An internal GRDB error.
	case internalError(String)

	/// An unclassified error.
	case unknown(Error)
}

// MARK: - Bridging from GRDB.DatabaseError

extension DatabaseError: CustomStringConvertible {
	public var description: String {
		switch self {
		case .recordNotFound:
			"Record not found in database"
		case .corruptedData:
			"Database corruption detected"
		case .validationFailed(let details):
			"Validation failed: \(details)"
		case .constraintViolation(let details):
			"Constraint violation: \(details)"
		case .databaseBusy:
			"Database locked (SQLITE_BUSY)"
		case .operationInterrupted:
			"Operation interrupted (SQLITE_INTERRUPT)"
		case .operationAborted:
			"Operation aborted (SQLITE_ABORT)"
		case .transactionRolledBack(let reason):
			"Transaction rolled back: \(reason)"
		case .uncommittedTransaction:
			"Uncommitted transaction detected"
		case .migrationFailed(let details):
			"Migration failed: \(details)"
		case .schemaVersionMismatch(let expected, let actual):
			"Schema version mismatch: expected \(expected), got \(actual)"
		case .schemaError(let details):
			"Schema error: \(details)"
		case .diskFull:
			"Disk full (SQLITE_FULL)"
		case .databaseFileNotFound:
			"Database file not found (SQLITE_CANTOPEN)"
		case .permissionDenied:
			"Permission denied (SQLITE_PERM/SQLITE_READONLY)"
		case .ioError(let details):
			"I/O error: \(details)"
		case .initializationFailed(let details):
			"Database initialization failed: \(details)"
		case .configurationError(let details):
			"Configuration error: \(details)"
		case .connectionTimeout:
			"Connection timeout"
		case .sqlSyntaxError(let details):
			"SQL syntax error: \(details)"
		case .sqlCompilationError(let details):
			"SQL compilation error: \(details)"
		case .unknownTableOrColumn(let details):
			"Unknown table or column: \(details)"
		case .queryExecutionFailed(let details):
			"Query execution failed: \(details)"
		case .decodingFailed(let details):
			"Decoding failed: \(details)"
		case .encodingFailed(let details):
			"Encoding failed: \(details)"
		case .unsupportedDataType(let details):
			"Unsupported data type: \(details)"
		case .observationSetupFailed(let details):
			"Observation setup failed: \(details)"
		case .observationFailed(let details):
			"Observation failed: \(details)"
		case .internalError(let details):
			"Internal error: \(details)"
		case .unknown(let error):
			"Unknown error: \(error.localizedDescription)"
		}
	}
	
	/// Maps a `GRDB.DatabaseError` into a domain-level ``DatabaseError``.
	///
	/// - Parameter grdbError: The error thrown by GRDB.
	/// - Returns: The matching domain-level error.
	public static func from(_ grdbError: GRDB.DatabaseError) -> DatabaseError {
		switch grdbError.resultCode {
		case .SQLITE_BUSY:
			return .databaseBusy
		case .SQLITE_INTERRUPT:
			return .operationInterrupted
		case .SQLITE_ABORT:
			return .operationAborted
		case .SQLITE_PERM, .SQLITE_READONLY:
			return .permissionDenied
		case .SQLITE_IOERR:
			return .ioError(grdbError.localizedDescription)
		case .SQLITE_CORRUPT:
			return .corruptedData
		case .SQLITE_FULL:
			return .diskFull
		case .SQLITE_CANTOPEN:
			return .databaseFileNotFound
		case .SQLITE_CONSTRAINT:
			return .constraintViolation(grdbError.localizedDescription)
		case .SQLITE_SCHEMA:
			return .schemaError(grdbError.localizedDescription)
		default:
			let message = grdbError.localizedDescription.lowercased()
			
			if message.contains("syntax") {
				return .sqlSyntaxError(grdbError.localizedDescription)
			} else if message.contains("no such table") || message.contains("no such column") {
				return .unknownTableOrColumn(grdbError.localizedDescription)
			} else if message.contains("foreign key") {
				return .constraintViolation(grdbError.localizedDescription)
			} else if message.contains("unique") {
				return .constraintViolation(grdbError.localizedDescription)
			} else {
				return .unknown(grdbError)
			}
		}
	}
}

// MARK: - Helper accessors

extension DatabaseError {

	/// Whether the error is transient and retrying the operation may succeed.
	public var isRetryable: Bool {
		switch self {
		case .databaseBusy, .connectionTimeout, .ioError:
			return true
		default:
			return false
		}
	}

	/// Whether the error is critical and typically requires restarting the application.
	public var isCritical: Bool {
		switch self {
		case .corruptedData, .schemaVersionMismatch, .internalError:
			return true
		default:
			return false
		}
	}

	/// A short category label for analytics and grouping.
	public var category: String {
		switch self {
		case .recordNotFound, .corruptedData, .validationFailed, .constraintViolation:
			return "data"
		case .databaseBusy, .operationInterrupted, .operationAborted, .transactionRolledBack, .uncommittedTransaction:
			return "concurrency"
		case .migrationFailed, .schemaVersionMismatch, .schemaError:
			return "migration"
		case .diskFull, .databaseFileNotFound, .permissionDenied, .ioError:
			return "filesystem"
		case .initializationFailed, .configurationError, .connectionTimeout:
			return "configuration"
		case .sqlSyntaxError, .sqlCompilationError, .unknownTableOrColumn, .queryExecutionFailed:
			return "sql"
		case .decodingFailed, .encodingFailed, .unsupportedDataType:
			return "serialization"
		case .observationSetupFailed, .observationFailed:
			return "observation"
		case .internalError, .unknown:
			return "internal"
		}
	}
}
