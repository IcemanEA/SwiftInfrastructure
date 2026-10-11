# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`SwiftInfrastructure` debuts publicly at version `0.1.0`. This is the initial public release, produced after a pre-publication API clean-up pass removed app-specific hardcoded values inherited from the package's origin project.

## [Unreleased]

## [0.3.0] — 2026-10-12

### Added

- `InfraTestSupport`: `LockedState<Value>`, a `Sendable` lock-protected container for writing test doubles of protocols with synchronous requirements.
- Test targets `InfraNotificationsTests` and `InfraFileCacheTests`.
- `InfraNotifications`: `deviceToken(timeout:)` accepts `.infinity` to wait until a token arrives or the task is cancelled; a negative or NaN timeout does not wait.
- `InfraFileCache`: `FileDownloadService.init` takes an optional `sessionConfiguration: URLSessionConfiguration = .default`, so tests can serve downloads through a custom `URLProtocol`.

### Changed

- **BREAKING** The package compiles in the Swift 6 language mode (`swiftLanguageModes: [.v6]`) and its public API is `Sendable`. Consumers in Swift 6 mode import every product without `@preconcurrency`. Consumers in Swift 5 mode are unaffected by the mode itself; the API changes below apply to both. Every public protocol now inherits `Sendable`, so your own types that conform to one — an `INetworkRequest`, an `ILogger`, an `IDatabaseMigrator`, a `MaskStringConvertible` credential wrapper, a hand-written test double — must be `Sendable` too: use value types or `let` properties of `Sendable` types, an actor, or `LockedState` in test code.
- **BREAKING** `InfraCore`: `AppFileManager.init(fileManager:logger:)` is now `init(logger:)`; the service always uses `FileManager.default`, which is thread-safe. `FileManager` is not `Sendable`, so a stored instance would make the service non-`Sendable`. Remove the `fileManager:` argument.
- **BREAKING** `InfraUserDefaults`: `UserDefaultsRepository.init(userDefaults:)` is now `init(suiteName: String? = nil)`; `nil` selects `UserDefaults.standard`. `UserDefaults` is not `Sendable`, so the repository keeps the suite name and resolves the store on each access. Replace `UserDefaultsRepository(userDefaults: UserDefaults(suiteName: "x")!)` with `UserDefaultsRepository(suiteName: "x")`; `UserDefaultsRepository()` is unchanged.
- **BREAKING** `InfraDatabase`: `DatabaseService.init(logger:databaseName:bundleID:)` now `throws` and opens the database itself; `dbPool` is a non-optional `let`; `setup(with:)` is replaced by `migrate(with:) async throws`, which takes a non-optional migrator. Construct the service with `try`, call `try await service.migrate(with: migrator)` where `setup(with:)` was called, and remove `guard let dbPool` unwrapping. `IDatabaseService` and `IDatabaseMigrator` are `Sendable`, so a migrator must hold only `Sendable` state.
- **BREAKING** `InfraNotifications`: `waitForDeviceToken(completion:)` is removed. Use `deviceToken(timeout:) async -> String?`, which returns the token, or `nil` on timeout or task cancellation, so a task group racing it against a timer can always finish; or iterate `deviceTokens()`, which yields the latest token and every change. `notifyTokenReceived(_:)` is now `async`: call it as `Task { await manager.notifyTokenReceived(token) }` from the app delegate.
- **BREAKING** `InfraNotifications`: `NotificationManager.init(center:logger:)` is now `init(logger:)`; the manager uses `UNUserNotificationCenter.current()`, because the center is not `Sendable`. Remove the `center:` argument.
- **BREAKING** `InfraFileCache`: `FileDownloadService` is an actor instead of an `NSObject` subclass, and `progressHandler` changes from `((Double) -> Void)?` to `(@Sendable (Double) -> Void)?`. The handler is now called on the service's executor, not on the main queue: hop to the main actor inside the handler before touching UI. A closure that captures non-`Sendable` state must be rewritten to capture only `Sendable` values.
- **BREAKING** `InfraNetwork`: `HTTPBody.json`, `.formData`, `.jsonArray` and `Parameters.url` carry `[String: any Sendable]` (`[[String: any Sendable]]` for `jsonArray`) instead of `[String: Any]`. Change the annotation where a dictionary is built in a variable; literals passed inline compile unchanged. The serialized bytes are the same. `INetworkClient.fetch` requires `T: Decodable & Sendable`: make every response type you decode `Sendable`.
- **BREAKING** `InfraTestSupport`: every mock is `Sendable`. `MockLogger`, `MockKeychainRepository`, `MockUserDefaultsRepository`, `MockNotificationManager` and `MockPdfCertificateGenerator` keep their API and keep their state in `LockedState`. `MockFileDownloadService` is an actor: `clearActiveDownloads()` and `activeDownloadCount` must be awaited. `MockNotificationManager` follows the new token API: `deviceToken(timeout:)` returns the last reported token or `deviceTokenResult` (default `"mock_device_token"`), and `reportedTokens` records every reported token.
- `InfraFileCache`: a non-2xx response is reported as `.serverError(statusCode:)` with the actual HTTP status; previously the code was always `-1011`.

### Fixed

- `InfraFileCache`: `cancelDownload` now completes the waiting `downloadFile` caller with `.failure(.internalError)`; previously that caller never returned.
- `InfraFileCache`: cancelling the task that awaits `downloadFile` or `resumeDownload` now releases that caller with `.failure(.internalError)`; the download goes on for any other caller, and `cancelDownload` still stops it. Previously the caller stayed suspended until the network finished.
- `InfraFileCache`: a file that finishes moving into place while its download is being cancelled is removed, so a cancelled download leaves nothing behind.
- `InfraFileCache`: `pauseDownload` no longer fails the waiting `downloadFile` caller. The caller keeps waiting, and `resumeDownload` continues the download (or restarts it when the server provided no resume data); both callers receive the final result. Previously a paused download could never be resumed. A `resumeDownload` call made while the pause is still in progress returns `.failure(.downloadInProgress)` instead of restarting from zero.

## [0.2.0] — 2026-10-07

### Added

- Continuous integration on GitHub Actions: every push to `master` and every pull request builds the package and runs the full test suite with Xcode 26.6 on an iOS Simulator, plus a test-hygiene check.
- Swift Testing test targets for `InfraCore`, `InfraNetwork`, `InfraSearch`, `InfraUserDefaults`, `InfraPdf`, `InfraImageMetadata` and `InfraTestSupport`, run with `xcodebuild test -scheme SwiftInfrastructure-Package` on an iOS Simulator.
- `InfraKeychain` test target: `KeychainRepository` is tested over an in-memory store, without the system Keychain. No public API change.
- `InfraTestSupport`: `MockLogger`, a recording `ILogger` for asserting on log calls.
- `InfraTestSupport`: `MockPdfCertificateGenerator`, a configurable `IPdfCertificateGenerator`.
- `InfraUserDefaults`: `UserDefaultsKey.defaultValue` is now `public`.

### Changed

- **BREAKING** `InfraPdf`: `PdfCertificateGenerator` and `PdfTemplateCertificateGenerator` now require `logger: ILogger` in their initializers, and `InfraPdf` depends on `InfraCore`. Pass the app's logger where the generators are constructed.
- `InfraPdf`: `CertificateTextItem.fontName` is now read as a comma-separated list of PostScript font names in priority order; the first installed font is used. When none is installed the item is drawn with the system font and a warning with the original value is logged. Previously such an item was silently left out of the certificate. A single name without commas behaves as before.
- `InfraSearch`: results with equal relevance are now ordered by display name. Previously their order depended on dictionary iteration and could change between launches.
- `InfraTestSupport`: `MockUserDefaultsRepository` is now an in-memory store that falls back to each key's declared default. Previously every read returned `nil` and writes were discarded; tests that relied on that will see stored values.
- `InfraTestSupport`: `MockKeychainRepository` no longer prints every operation to stdout. Pass `logger:` to its initializer to receive those messages through an `ILogger`; `printCurrentState()` still prints on request.
- `InfraUserDefaults`: the `hasValue(for:)` documentation now states that seeded defaults count as stored values.

## [0.1.0] — 2026-04-24

### Added

- `InfraCore` — logging (`ILogger`, `Logger`, `LogManager`, `LogCategory`, `LogLevel`) and file-system utilities (`IAppFileManager`, `AppFileManager`); `MaskStringConvertible` for credential-wrapping types.
- `InfraDatabase` — SQLite access and consumer-supplied migrations on top of GRDB (`IDatabaseService`, `DatabaseService`, `IDatabaseMigrator`, `DatabaseInfo`, `TableInfo`, `DatabaseError`).
- `InfraNetwork` — HTTP client and request builder (`INetworkClient`, `NetworkClient`, `INetworkRequestBuilder`, `NetworkRequestBuilder`, `NetworkRequest`), auth tokens (`AuthToken`, `BasicAuth`), device-credentials generator (`DeviceCredentialsGenerator`), request/response models (`HTTPMethod`, `HTTPHeader`, `HTTPBody`, `Parameters`, `ContentType`, `NetworkError`, `ResponseStatus`, `ResponseHealth`, `ResponseCode`, `EmptyResponse`, `Password`).
- `InfraKeychain` — secure credential storage (`IKeychainRepository`, `KeychainRepository`, `KeychainService`, `SecretToken`, `SecretTokenType`).
- `InfraUserDefaults` — typed `UserDefaults` access (`IUserDefaultsRepository`, `UserDefaultsRepository`, `UserDefaultsKey`, `KeyCategory`).
- `InfraNotifications` — push/local notification manager and authorization (`INotificationManager`, `NotificationManager`, `NotificationAuthorizationStatus`).
- `InfraPdf` — PDF/JPG certificate generation (`IPdfCertificateGenerator`, `PdfCertificateGenerator`, `PdfTemplateCertificateGenerator`, `CertificateGeneratorFactory`, `CertificateData`, `CertificateTextItem`, `CertificateTemplateType`, `PdfGeneratorError`).
- `InfraFileCache` — remote file download with progress, pause, resume, and cancel (`IFileDownloadService`, `FileDownloadService`, `FileDownloadError`).
- `InfraImageMetadata` — image dimension extraction without full decode (`ImageMetadataService`).
- `InfraSearch` — smart string search with relevance ranking (`ISearchService`, `SearchService`).
- `InfraTestSupport` — public `Mock*` types for consumer test targets (`MockKeychainRepository`, `MockUserDefaultsRepository`, `MockNotificationManager`, `MockFileDownloadService`).

### Note on versioning

This is a pre-1.0 release. Per semver, the public API may still introduce breaking changes on minor version bumps (`0.1.x` → `0.2.0`, …) until the project reaches `1.0.0`. Consumers are recommended to pin with `.upToNextMinor(from: "0.1.0")` rather than `.upToNextMajor(from: "0.1.0")`. Breaking changes will be documented under their release entry in this file.

[Unreleased]: https://github.com/IcemanEA/SwiftInfrastructure/compare/0.1.0...HEAD
[0.1.0]: https://github.com/IcemanEA/SwiftInfrastructure/releases/tag/0.1.0
