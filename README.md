[![License: MIT](https://img.shields.io/github/license/IcemanEA/SwiftInfrastructure)](LICENSE)
[![Latest tag](https://img.shields.io/github/v/tag/IcemanEA/SwiftInfrastructure?label=version)](https://github.com/IcemanEA/SwiftInfrastructure/releases)
[![iOS 15+](https://img.shields.io/badge/iOS-15%2B-blue)](#compatibility)
[![Swift 6.2](https://img.shields.io/badge/Swift_Tools-6.2-orange)](#compatibility)

# SwiftInfrastructure

Reusable iOS infrastructure layer extracted from a production app. Granular Swift Package — every module is shipped as a separate library, consumers opt in per module.

## At a glance

`SwiftInfrastructure` is eleven small, opt-in infrastructure libraries: logging, GRDB-backed database setup, HTTP networking, Keychain credentials, typed UserDefaults, push/local notifications, PDF certificate generation, resumable file downloads, image metadata, smart string search, and a `Mock*` test-support module. There is no umbrella product — each module is its own `import`. If you only need the keychain helpers, you add `InfraKeychain` and nothing else.

## Requirements

- iOS 15+
- Swift tools 6.2+
- Swift language mode 5

## Products

| Library | Purpose | External dependency |
|---------|---------|---------------------|
| `InfraCore`          | Logging (`ILogger`, `LogManager`, `LogCategory`, `LogLevel`) and file-system utilities (`IAppFileManager`, `AppFileManager`) | — |
| `InfraDatabase`      | SQLite access and migration via GRDB (`IDatabaseService`, `DatabaseService`, `IDatabaseMigrator`) | [GRDB](https://github.com/groue/GRDB.swift) |
| `InfraNetwork`       | HTTP client and request builder (`INetworkClient`, `INetworkRequestBuilder`), auth, request/response models | — |
| `InfraKeychain`      | Secure credential storage (`IKeychainRepository`, `KeychainService`, `SecretToken`) | — |
| `InfraUserDefaults`  | Type-safe `UserDefaults` access (`IUserDefaultsRepository`, `UserDefaultsKey`) | — |
| `InfraNotifications` | Push notification manager and authorization (`INotificationManager`) | — |
| `InfraPdf`           | PDF/JPG certificate generation (`IPdfCertificateGenerator`, `CertificateGeneratorFactory`) | — |
| `InfraFileCache`     | Remote file download with progress/resume (`IFileDownloadService`) | — |
| `InfraImageMetadata` | Image dimension extraction (`ImageMetadataService`) | — |
| `InfraSearch`        | Smart string search with relevance ranking (`ISearchService`) | — |
| `InfraTestSupport`   | Public `Mock*` implementations for unit tests | all Infra\* targets |

No umbrella product — consumers import only what they use.

## Integration

### Local development

```swift
.package(path: "../SwiftInfrastructure")
```

### Remote (GitHub)

```swift
.package(url: "https://github.com/IcemanEA/SwiftInfrastructure.git", .upToNextMinor(from: "0.1.0"))
```

### Xcode project

`File → Add Package Dependencies…` and select the `Infra*` products the target needs. `InfraTestSupport` should be linked **only** from test targets.

## Example imports

```swift
// Production code
import InfraCore         // LogManager
import InfraNetwork      // INetworkClient, NetworkError
import InfraKeychain     // IKeychainRepository
import InfraDatabase     // IDatabaseService

// Test code
import InfraTestSupport  // MockKeychainRepository, MockUserDefaultsRepository, ...
```

## Quick start per module

Each snippet below shows the canonical construction of the module's primary entry point. Replace `"com.example.myapp"` with your own bundle identifier or reverse-DNS namespace.

### InfraCore — logging

```swift
import InfraCore

let logger = Logger(
    minimumLogLevel: .info,
    enableConsoleLogging: true,
    enableOSLogging: true,
    queueLabel: "com.example.myapp.log",
    subsystemPrefix: "com.example.myapp"
)

// Per-category wrapper in a service:
final class MyService {
    private let logger: LogManager
    init(logger: ILogger) {
        self.logger = LogManager(logger: logger, category: .network)
    }
    func fetch() {
        logger.info("Fetching data…")
    }
}
```

### InfraDatabase — setup with migrations

```swift
import InfraCore
import InfraDatabase
import GRDB

struct MyMigrator: IDatabaseMigrator {
    func registerMigrations(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try db.create(table: "items") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text).notNull()
            }
        }
    }
}

let db = DatabaseService(
    logger: logger,
    databaseName: "app.sqlite",
    bundleID: "com.example.myapp"
)
try await db.setup(with: MyMigrator())
```

### InfraNetwork — build and fetch a request

```swift
import InfraCore
import InfraNetwork

let builder = NetworkRequestBuilder(
    baseUrl: URL(string: "https://api.example.com")!
)
let client = NetworkClient(
    session: .shared,
    requestBuilder: builder,
    logger: LogManager(logger: logger, category: .network)
)

struct Item: Decodable { let id: Int; let name: String }
let request = NetworkRequest(method: .get, path: "/items")
let result: Result<[Item], NetworkError> = await client.fetch(request)
```

### InfraKeychain — store a JWT

```swift
import InfraKeychain

let keychain: IKeychainRepository = KeychainRepository(prefix: "com.example.myapp.")

let token = SecretToken(type: .jwtToken, rawValue: "eyJhbGciOi…")
_ = keychain.saveSecret(token)

if let stored = keychain.getSecret(for: .jwtToken) {
    // stored.rawValue — the token value
    // description prints as "***********" thanks to MaskStringConvertible
}
```

### InfraUserDefaults — typed settings

```swift
import InfraUserDefaults

let settings: IUserDefaultsRepository = UserDefaultsRepository()

let completed = settings.getBool(for: .onboardingCompleted) ?? false
if !completed {
    // show onboarding…
    settings.setValue(true, for: .onboardingCompleted)
}
```

`UserDefaultsKey` is an enum — every key is declared there with its `defaultValue`, `category`, and `isCritical` metadata. Extend it to add new settings; free-form string keys are deliberately not supported.

### InfraNotifications — request permission and schedule

```swift
import InfraNotifications

let manager: INotificationManager = NotificationManager(/* … */)

let granted = await manager.requestPermission()
guard granted else { return }

_ = await manager.scheduleNotification(
    id: "reminder-1",
    title: "Reminder",
    body: "Don't forget to stretch.",
    timeInterval: 60 * 30,
    userInfo: ["kind": "stretch"]
)
```

### InfraPdf — generate a certificate

```swift
import InfraPdf

let factory = CertificateGeneratorFactory(
    imageGenerator: PdfTemplateCertificateGenerator(),
    pdfGenerator: PdfCertificateGenerator()
)

let templateURL = Bundle.main.url(forResource: "certificate", withExtension: "jpg")!
let generator = factory.getGenerator(for: templateURL)

let data = CertificateData(
    templateURL: templateURL,
    items: [/* CertificateTextItem… */]
)
let (preview, pdf) = try await generator.generateCertificate(
    templateImagePath: templateURL.path,
    certificateData: data
)
```

### InfraFileCache — download with progress

```swift
import InfraFileCache

let service: IFileDownloadService = FileDownloadService(
    logger: logger,
    appFileManager: AppFileManager(logger: logger)
)

let remote = URL(string: "https://example.com/big.pdf")!
let result = await service.downloadFile(
    from: remote,
    to: "Documents/big.pdf",
    progressHandler: { fraction in
        print("progress: \(Int(fraction * 100))%")
    }
)
```

### InfraImageMetadata — dimensions without full decode

```swift
import InfraImageMetadata

if let size = ImageMetadataService.getImageDimensions(from: localURL) {
    let height = ImageMetadataService.calculateHeight(for: size, targetWidth: 300)
    // Lay out a 300-wide image at the calculated height.
}
```

### InfraSearch — relevance-ranked search

```swift
import InfraSearch

let search: ISearchService = SearchService()
await search.configure(items: [
    "Apple":  "apple fruit red",
    "Banana": "banana fruit yellow",
    "Cherry": "cherry fruit red"
])

let matches = await search.search(query: "red fruit")
// → ["Apple", "Cherry"]
```

### InfraTestSupport — mocks for your test targets

```swift
import Testing
@testable import MyApp
import InfraKeychain
import InfraTestSupport

@Suite("AuthFlow")
struct AuthFlowTests {
    @Test("Saves JWT on login")
    func savesJWT() {
        let mock = MockKeychainRepository()
        let sut = AuthFlow(keychain: mock)
        sut.login(token: "eyJ…")
        #expect(mock.getSecret(for: .jwtToken)?.rawValue == "eyJ…")
    }
}
```

`InfraTestSupport` should be linked **only from test targets**. Using `MockKeychainRepository.withRealData()` or `.withFailures()` factory methods covers common fixture scenarios.

## Compatibility

| | |
|---|---|
| Platforms | iOS 15+ |
| Swift tools | 6.2+ |
| Swift language mode | 5 |
| External deps | `GRDB.swift` `.upToNextMinor(from: "7.7.1")` — linked only from `InfraDatabase` |

`swift build` on macOS fails with a diagnostic about GRDB requiring macOS 10.15 — the package is iOS-only. Use Xcode or `xcodebuild -destination 'generic/platform=iOS Simulator' build`.

## Versioning

This project follows [semantic versioning](https://semver.org/spec/v2.0.0.html) with the pre-1.0 convention: **breaking changes are permitted on minor bumps** (`0.1.x` → `0.2.0`) until a `1.0.0` tag is cut. Consumers are recommended to pin with `.upToNextMinor(from:)`. Release history and migration notes live in [`CHANGELOG.md`](CHANGELOG.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for code style, architectural patterns, file-header format, and pull-request conventions.

## License

Released under the MIT License — see [`LICENSE`](LICENSE).
