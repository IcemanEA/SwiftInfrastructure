# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`SwiftInfrastructure` debuts publicly at version `0.1.0`. This is the initial public release, produced after a pre-publication API clean-up pass removed app-specific hardcoded values inherited from the package's origin project.

## [Unreleased]

### Added

- Continuous integration on GitHub Actions: every push to `master` and every pull request builds the package and runs the full test suite with Xcode 26.6 on an iOS Simulator, plus a test-hygiene check.
- Swift Testing test targets for `InfraCore`, `InfraNetwork`, `InfraSearch`, `InfraUserDefaults`, `InfraPdf`, `InfraImageMetadata` and `InfraTestSupport`, run with `xcodebuild test -scheme SwiftInfrastructure-Package` on an iOS Simulator.
- `InfraKeychain` test target: `KeychainRepository` is tested over an in-memory store, without the system Keychain. No public API change.
- `InfraTestSupport`: `MockLogger`, a recording `ILogger` for asserting on log calls.
- `InfraTestSupport`: `MockPdfCertificateGenerator`, a configurable `IPdfCertificateGenerator`.
- `InfraUserDefaults`: `UserDefaultsKey.defaultValue` is now `public`.

### Changed

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
