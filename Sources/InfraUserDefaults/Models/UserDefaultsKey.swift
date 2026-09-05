//
//  UserDefaultsKey.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 24.06.2025.
//

import Foundation

// MARK: - KeyCategory

/// A grouping label applied to each ``UserDefaultsKey`` case.
public enum KeyCategory: String, CaseIterable {

	/// Application-level state and update markers.
	case application = "application"

	/// User preferences and settings.
	case user = "user"

	/// Cache and transient data.
	case cache = "cache"

	/// Database-observed update markers.
	case dataBase = "dataBase"

	/// A human-readable label for the category, suitable for debug output.
	var description: String {
		switch self {
		case .application:
			return "Application Updates"
		case .user:
			return "User Preferences"
		case .cache:
			return "Cache & Temporary Data"
		case .dataBase:
			return "Database observed updates"
		}
	}
}

/// The set of known keys for values stored in `UserDefaults`.
///
/// ## Overview
///
/// This enum enumerates every setting the app is allowed to store in
/// `UserDefaults`. Each case carries a stable raw key, a debug-friendly
/// description, a grouping category, a criticality flag, and a default value.
/// Free-form string keys are deliberately not supported — to add a setting,
/// extend this enum and update the `switch` statements below.
///
/// ## Data categories
///
/// - **Application** — application-wide state.
/// - **User** — user-facing preferences and flags.
/// - **Cache** — transient values and timestamps.
/// - **Database** — database-observed update markers.
///
/// ```swift
/// let repository: IUserDefaultsRepository = UserDefaultsRepository()
///
/// // Check onboarding status.
/// let isCompleted = repository.getBool(for: .onboardingCompleted) ?? false
///
/// // Record a sync timestamp.
/// repository.setValue(Date().timeIntervalSince1970, for: .lastJwtSyncTime)
/// ```
public enum UserDefaultsKey: String, CaseIterable {

	/// Timestamp of the most recent application start, in seconds since the Unix epoch.
	case lastAppStartTime = "last_app_start_time"

	/// Whether the onboarding flow has been completed; `false` or missing means onboarding should be shown.
	case onboardingCompleted = "onboarding_completed"

	/// Timestamp of the most recent successful JWT-token sync, in seconds since the Unix epoch.
	case lastJwtSyncTime = "last_jwt_sync_time"

	/// Timestamp of the most recent successful news sync from the server, in seconds since the Unix epoch.
	case lastNewsSyncTime = "last_news_sync_time"

	/// Timestamp of the most recent successful conferences sync from the server, in seconds since the Unix epoch.
	case lastConferencesSyncTime = "last_conferences_sync_time"

	/// Timestamp of the most recent successful certificate-template sync from the server, in seconds since the Unix epoch.
	case lastCertificatesSyncTime = "last_certificates_sync_time"

	/// Timestamp of the most recent successful messages sync from the server, in seconds since the Unix epoch.
	case lastMessagesSyncTime = "last_messages_sync_time"

	/// Timestamp of the most recent successful sponsors sync from the server, in seconds since the Unix epoch.
	case lastSponsorsSyncTime = "last_sponsors_sync_time"

	/// Timestamp of the most recent successful clinics sync from the server, in seconds since the Unix epoch.
	case lastClinicsSyncTime = "last_clinics_sync_time"

	/// The reader's recent programme-search queries, newest first, as an array of strings.
	case recentProgramSearchQueries = "recent_program_search_queries"

	// MARK: - Computed Properties

	/// A human-readable label for the key, suitable for debug output.
	var description: String {
		switch self {
		case .lastAppStartTime:
			return "Last Application start Timestamp"
		case .onboardingCompleted:
			return "Onboarding Completion Status"
		case .lastJwtSyncTime:
			return "Last JWT Sync Timestamp"
		case .lastNewsSyncTime:
			return "Last News Sync Timestamp"
		case .lastConferencesSyncTime:
			return "Last Conferences Sync Timestamp"
		case .lastCertificatesSyncTime:
			return "Last Certificates Sync Timestamp"
		case .lastMessagesSyncTime:
			return "Last Messages Sync Timestamp"
		case .lastSponsorsSyncTime:
			return "Last Sponsors Sync Timestamp"
		case .lastClinicsSyncTime:
			return "Last Clinics Sync Timestamp"
		case .recentProgramSearchQueries:
			return "Recent Programme Search Queries"
		}
	}

	/// The grouping category for this key.
	var category: KeyCategory {
		switch self {
		case .lastAppStartTime:
			return .application
		case .onboardingCompleted, .recentProgramSearchQueries:
			return .user
		case .lastJwtSyncTime, .lastNewsSyncTime, .lastConferencesSyncTime:
			return .cache
		case .lastCertificatesSyncTime, .lastMessagesSyncTime, .lastSponsorsSyncTime, .lastClinicsSyncTime:
			return .cache
		}
	}

	/// Whether the key is critical enough to force a flush to disk on every write.
	var isCritical: Bool {
		switch self {
		case .onboardingCompleted:
			return true
		default:
			return false
		}
	}

	/// The default value the repository seeds into `UserDefaults` when no value is stored yet.
	var defaultValue: Any? {
		switch self {
		case .lastAppStartTime:
			return 0
		case .onboardingCompleted:
			return false
		case .lastJwtSyncTime, .lastNewsSyncTime, .lastConferencesSyncTime:
			return 0
		case .lastCertificatesSyncTime, .lastMessagesSyncTime, .lastSponsorsSyncTime, .lastClinicsSyncTime:
			return 0
		case .recentProgramSearchQueries:
			return [String]()
		}
	}
}
