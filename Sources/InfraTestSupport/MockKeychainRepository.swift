//
//  MockKeychainRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//


//
//  MockKeychainRepository.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 17.06.2025.
//

import Foundation
import InfraCore
import InfraKeychain

// MARK: - MockKeychainRepository

/// An in-memory mock implementation of ``IKeychainRepository`` for tests and previews.
///
/// ## Overview
///
/// Mirrors the behaviour of a real Keychain-backed repository but stores
/// tokens in a thread-safe in-memory dictionary. Intended for:
/// - Unit tests.
/// - UI tests.
/// - Development against stubbed backends.
/// - SwiftUI previews.
///
/// ## Capabilities
///
/// - In-memory storage (values are lost at process termination).
/// - Failure-simulation toggles for save / update / delete paths.
/// - Optional logging of every operation through an injected ``ILogger``; silent by default.
/// - Preset-token seeding.
/// - Thread-safe access via a concurrent `DispatchQueue` with barrier writes.
///
/// ## Examples
///
/// ### In tests
///
/// ```swift
/// func testTokenSaving() {
///     let mock = MockKeychainRepository()
///     let token = SecretToken(type: .jwtToken, rawValue: "test_token")
///
///     #expect(mock.saveSecret(token))
///     #expect(mock.getSecret(for: .jwtToken)?.rawValue == "test_token")
/// }
/// ```
///
/// ### In SwiftUI previews
///
/// ```swift
/// #Preview {
///     let mockRepo = MockKeychainRepository()
///     mockRepo.presetToken(.pushNotificationToken, value: "preview_fcm_token")
///     return ContentView()
///         .environmentObject(mockRepo)
/// }
/// ```
public final class MockKeychainRepository: IKeychainRepository {
	
	// MARK: - Private Properties
	
	/// The in-memory token store.
	private var tokens: [SecretTokenType: SecretToken] = [:]

	/// Failure-simulation flags used to exercise error paths in tests.
	private var shouldFailSave = false
	private var shouldFailUpdate = false
	private var shouldFailDelete = false

	/// Per-method invocation counters for assertion in tests.
	private var saveCallCount = 0
	private var updateCallCount = 0
	private var deleteCallCount = 0
	private var getCallCount = 0

	/// Concurrent queue that guards access to the in-memory store.
	private let queue = DispatchQueue(label: "MockKeychainRepository", attributes: .concurrent)

	/// Receives a message for every operation when a logger is injected; `nil` keeps the mock silent.
	private let logger: LogManager?
	
	// MARK: - Public Initializer
	
	/// Creates a new mock repository, optionally pre-seeded with tokens.
	///
	/// - Parameters:
	///   - presetTokens: Tokens to seed into the in-memory store, keyed by type.
	///   - logger: A logger that receives a message for every operation under the `.repository` category. Defaults to `nil`, which keeps the mock silent.
	public init(presetTokens: [SecretTokenType: String] = [:], logger: ILogger? = nil) {
		self.logger = logger.map { LogManager(logger: $0, category: .repository) }
		for (type, value) in presetTokens {
			let token = SecretToken(type: type, rawValue: value)
			tokens[type] = token
		}
	}
	
	// MARK: - IKeychainRepository Implementation
	
	public func getSecret(for type: SecretTokenType) -> SecretToken? {
		return queue.sync {
			getCallCount += 1
			let token = tokens[type]
			
			logger?.debug("🔍 MockRepo: Getting secret for \(type) - \(token != nil ? "Found" : "Not found")")
			return token
		}
	}
	
	public func saveSecret(_ token: SecretToken) -> Bool {
		return queue.sync(flags: .barrier) {
			saveCallCount += 1
			
			if shouldFailSave {
				logger?.warning("❌ MockRepo: Save failed (simulated) for \(token.type)")
				return false
			}
			
			tokens[token.type] = token
			logger?.debug("✅ MockRepo: Saved secret for \(token.type)")
			return true
		}
	}
	
	public func deleteSecret(for type: SecretTokenType) -> Bool {
		return queue.sync(flags: .barrier) {
			deleteCallCount += 1
			
			if shouldFailDelete {
				logger?.warning("❌ MockRepo: Delete failed (simulated) for \(type)")
				return false
			}
			
			let existed = tokens[type] != nil
			tokens.removeValue(forKey: type)
			
			logger?.debug("🗑️ MockRepo: Deleted secret for \(type) - \(existed ? "existed" : "didn't exist")")
			return true
		}
	}
	
	public func updateSecret(_ token: SecretToken) -> Bool {
		return queue.sync(flags: .barrier) {
			updateCallCount += 1
			
			if shouldFailUpdate {
				logger?.warning("❌ MockRepo: Update failed (simulated) for \(token.type)")
				return false
			}
			
			let existed = tokens[token.type] != nil
			tokens[token.type] = token
			
			logger?.debug("🔄 MockRepo: Updated secret for \(token.type) - \(existed ? "replaced existing" : "created new")")
			return true
		}
	}
	
	// MARK: - Mock Configuration Methods
	
	/// Seeds a token into the in-memory store.
	///
	/// - Parameters:
	///   - type: The kind of token to seed.
	///   - value: The raw token value.
	public func presetToken(_ type: SecretTokenType, value: String) {
		queue.sync(flags: .barrier) {
			let token = SecretToken(type: type, rawValue: value)
			tokens[type] = token
			logger?.debug("⚙️ MockRepo: Preset token for \(type)")
		}
	}
	
	/// Toggles simulation of save-operation failures.
	///
	/// - Parameter shouldFail: `true` to make every subsequent `saveSecret` return `false`.
	public func simulateSaveFailure(_ shouldFail: Bool = true) {
		queue.sync(flags: .barrier) {
			shouldFailSave = shouldFail
			logger?.debug("⚙️ MockRepo: Save failure simulation \(shouldFail ? "enabled" : "disabled")")
		}
	}
	
	/// Toggles simulation of update-operation failures.
	///
	/// - Parameter shouldFail: `true` to make every subsequent `updateSecret` return `false`.
	public func simulateUpdateFailure(_ shouldFail: Bool = true) {
		queue.sync(flags: .barrier) {
			shouldFailUpdate = shouldFail
			logger?.debug("⚙️ MockRepo: Update failure simulation \(shouldFail ? "enabled" : "disabled")")
		}
	}
	
	/// Toggles simulation of delete-operation failures.
	///
	/// - Parameter shouldFail: `true` to make every subsequent `deleteSecret` return `false`.
	public func simulateDeleteFailure(_ shouldFail: Bool = true) {
		queue.sync(flags: .barrier) {
			shouldFailDelete = shouldFail
			logger?.debug("⚙️ MockRepo: Delete failure simulation \(shouldFail ? "enabled" : "disabled")")
		}
	}
	
	/// Disables every failure-simulation flag.
	public func resetFailureSimulations() {
		queue.sync(flags: .barrier) {
			shouldFailSave = false
			shouldFailUpdate = false
			shouldFailDelete = false
			logger?.debug("⚙️ MockRepo: All failure simulations reset")
		}
	}
	
	// MARK: - Test Helper Methods
	
	/// Removes every token from the in-memory store.
	public func clearAllTokens() {
		queue.sync(flags: .barrier) {
			tokens.removeAll()
			logger?.debug("🧹 MockRepo: All tokens cleared")
		}
	}
	
	/// The number of tokens currently stored.
	public var tokenCount: Int {
		return queue.sync {
			return tokens.count
		}
	}
	
	/// Returns whether a token of the given type is currently stored.
	///
	/// - Parameter type: The token kind to check.
	/// - Returns: `true` when a token of that type exists in the store.
	public func hasToken(for type: SecretTokenType) -> Bool {
		return queue.sync {
			return tokens[type] != nil
		}
	}
	
	/// The token types currently present in the store.
	public var availableTokenTypes: [SecretTokenType] {
		return queue.sync {
			return Array(tokens.keys)
		}
	}
	
	/// A snapshot of per-method invocation counters, for assertion in tests.
	public var callCounts: (save: Int, update: Int, delete: Int, get: Int) {
		return queue.sync {
			return (save: saveCallCount, update: updateCallCount, delete: deleteCallCount, get: getCallCount)
		}
	}
	
	/// Resets every invocation counter back to zero.
	public func resetCallCounts() {
		queue.sync(flags: .barrier) {
			saveCallCount = 0
			updateCallCount = 0
			deleteCallCount = 0
			getCallCount = 0
			logger?.debug("📊 MockRepo: Call counts reset")
		}
	}
	
	/// Prints the current state of the mock — stored tokens, call counts, and simulation flags — to the console.
	public func printCurrentState() {
		queue.sync {
			print("📊 MockRepo State:")
			print("  - Tokens count: \(tokens.count)")
			print("  - Available types: \(tokens.keys.map { $0.rawValue })")
			print("  - Call counts: save(\(saveCallCount)), update(\(updateCallCount)), delete(\(deleteCallCount)), get(\(getCallCount))")
			print("  - Failure simulations: save(\(shouldFailSave)), update(\(shouldFailUpdate)), delete(\(shouldFailDelete))")
		}
	}
	
	public func clearAllSecrets() -> Bool {
		return queue.sync(flags: .barrier) {
			let tokenCount = tokens.count
			tokens.removeAll()
			logger?.debug("🧹 MockRepo: Cleared all secrets (\(tokenCount) tokens removed)")
			return true
		}
	}
}

// MARK: - MockKeychainRepository + Test Scenarios

public extension MockKeychainRepository {
	
	/// Builds a mock seeded with realistic-looking token values, for tests that exercise full flows.
	static func withRealData() -> MockKeychainRepository {
		let mock = MockKeychainRepository(presetTokens: [
			.pushNotificationToken: "fcm_AAAAxxxxxxxx:APA91bHxxxxxxxx",
			.jwtToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
		])
		return mock
	}
	
	/// Builds a mock with every failure-simulation flag enabled, for tests that verify error-handling paths.
	static func withFailures() -> MockKeychainRepository {
		let mock = MockKeychainRepository()
		mock.simulateSaveFailure()
		mock.simulateUpdateFailure()
		mock.simulateDeleteFailure()
		return mock
	}
	
	/// Builds an empty mock for tests that exercise initial-state behaviour.
	static func empty() -> MockKeychainRepository {
		return MockKeychainRepository()
	}
}

// MARK: - Usage Examples in Comments

/*
 
 // MARK: - Usage Examples
 
 // 1. Basic Unit Test
 func testBasicTokenOperations() {
     let mock = MockKeychainRepository()
     let token = SecretToken(type: .notification, rawValue: "test_fcm_token")
     
     // Test save
     XCTAssertTrue(mock.saveSecret(token, for: .notification))
     XCTAssertEqual(mock.tokenCount, 1)
     
     // Test get
     let retrieved = mock.getSecret(for: .notification)
     XCTAssertNotNil(retrieved)
     XCTAssertEqual(retrieved?.rawValue, "test_fcm_token")
     
     // Test delete
     XCTAssertTrue(mock.deleteSecret(for: .notification))
     XCTAssertEqual(mock.tokenCount, 0)
 }
 
 // 2. Error Simulation Test
 func testErrorHandling() {
     let mock = MockKeychainRepository()
     mock.simulateSaveFailure()
     
     let token = SecretToken(type: .authorization, rawValue: "auth_token")
     XCTAssertFalse(mock.saveSecret(token, for: .authorization))
     
     mock.resetFailureSimulations()
     XCTAssertTrue(mock.saveSecret(token, for: .authorization))
 }
 
 // 3. SwiftUI Preview
 #Preview {
     let mock = MockKeychainRepository.withRealData()
     
     return LoginView()
         .environmentObject(mock as IKeychainRepository)
 }
 
 // 4. Performance Test
 func testConcurrentAccess() {
     let mock = MockKeychainRepository()
     let expectation = XCTestExpectation(description: "Concurrent operations")
     expectation.expectedFulfillmentCount = 100
     
     for i in 0..<100 {
         DispatchQueue.global().async {
             let token = SecretToken(type: .notification, rawValue: "token_\(i)")
             _ = mock.saveSecret(token, for: .notification)
             expectation.fulfill()
         }
     }
     
     wait(for: [expectation], timeout: 5.0)
     XCTAssertEqual(mock.callCounts.save, 100)
 }
 
 */
