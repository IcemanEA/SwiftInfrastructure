# Contributing to SwiftInfrastructure

Thanks for considering a contribution. This package is maintained with a strong bias toward small, focused changes and consistency with the existing house style. The sections below capture what a reviewer will be looking for.

## How to contribute

1. Fork the repository and create a branch off `main`.
2. Make one logical change per pull request.
3. Keep the diff minimal — no opportunistic refactors, no style reformatting outside the lines you are changing.
4. Open a pull request against `main`. Describe *why* the change is needed as well as *what* it does.
5. Expect review comments. The bar is house-style consistency over individual preference.

## Code style

- **Tabs** for indentation. Never spaces. All existing files use tabs; new files must match.
- **Preserve existing empty lines exactly.** Do not add or remove blank lines as a side effect of an unrelated edit. Xcode sometimes inserts indented blank lines inside type bodies (`\t\n`) — keep them.
- **English for implementation-internal `//` comments** where practical. Historical Russian inline comments may remain until a deliberate translation change.
- **No extra methods, properties, or helpers unless the feature requires them.** Three similar lines is preferable to a premature abstraction.

## Architectural patterns

This is a library, not an app. Consumers import `Infra*` products and compose them against their own domain code. The package ships no ViewModels, no Coordinator, no DIContainer.

- **Protocol-first with `I`-prefix.** Every service exposes `IFoo` (public protocol) and `Foo` (public struct / final class / actor). New services follow the same shape so `InfraTestSupport` can ship a `MockFoo`.
- **`LogManager`-per-category.** Services that log take an `ILogger` in `init`, wrap it once as `LogManager(logger: logger, category: .{category})`, and call the proxy methods without passing a category at each call site. See `DatabaseService.init` and `NetworkClient.init` for the template.
- **`MaskStringConvertible` for credential-wrapping types.** Any type that carries a secret (tokens, passwords, session identifiers) conforms to `MaskStringConvertible` from `InfraCore`, which replaces `description` / `debugDescription` with `"***********"` to prevent accidental log leaks.
- **`UserDefaultsKey` enum — no free-form string keys.** Every setting stored through `IUserDefaultsRepository` goes through the `UserDefaultsKey` enum, which carries `description`, `category`, `isCritical`, and `defaultValue` for each case.
- **`Mock*` lives in `InfraTestSupport`.** When you add or change a protocol in any `Infra*` module, update the matching `Mock*` in `InfraTestSupport` in the same pull request. Consumers rely on these for their own test targets; drift between protocol and mock is a silent breakage.
- **Actors for shared mutable state.** `SearchService` is `actor`-based. New concurrent services prefer `actor` over `class + lock`.

## Docstring policy

Public declarations **must** carry English `///` docstrings written in DocC style. Pull requests that introduce Russian-language docstrings on new public API will be asked to revise before merge.

Inline `//` comments and MARK lines are contributor-facing — not public API — and some historical Russian inline comments remain. Contributions that translate them to English are welcome as stand-alone cleanup PRs.

### DocC-style template

```swift
/// A short, one-sentence summary describing what this declaration is.
///
/// ## Overview
///
/// Longer prose where it helps — design intent, trade-offs, typical usage.
/// Cross-reference other types with backticks (`` `ILogger` ``) so DocC can
/// auto-link them.
///
/// ```swift
/// let example = MyService(config: …)
/// try example.doThing()
/// ```
///
/// - Parameter foo: What `foo` represents.
/// - Parameter bar: What `bar` represents.
/// - Returns: What the function returns, and under which conditions.
/// - Throws: Which errors and when.
```

Use Apple-style callouts (`> Important:`, `> Warning:`, `> Note:`, `> Tip:`) for emphasis where appropriate.

## File header format

Every source file under `Sources/` opens with a standard header block:

```swift
//
//  YourType.swift
//  SwiftInfrastructure
//
//  Created by Your Name on DD.MM.YYYY.
//
```

- The package-name line (`//  SwiftInfrastructure`) must match exactly.
- The filename line must match the actual filename (watch for typos after renames).
- The `Created by` line records the original author — preserve it on every subsequent edit. New files name the contributor who created them.

## Build

Use Xcode. The package targets iOS 15 and only builds cleanly for an iOS destination:

```bash
xcodebuild -scheme SwiftInfrastructure-Package -destination 'generic/platform=iOS Simulator' build
```

`SwiftInfrastructure-Package` is the package-level scheme Xcode generates; it builds every library and test target. Per-product schemes (`InfraCore`, `InfraNetwork`, …) build a single library.

`swift build` on macOS **fails** with a diagnostic about `InfraDatabase` requiring macOS 10.15 through GRDB. This is expected — the package does not support macOS as a build platform.

When hacking on the package inside the Xcode UI, use Product → Build (⌘B). No separate generator step is required.

## Pull requests

- One logical change per PR.
- Subject line in imperative mood: "Add ISearchService.configure overload for ordered input" — not "Added …", not "Adds …".
- **Breaking changes** to any `public` API must be flagged with a `BREAKING:` prefix in the subject: `BREAKING: remove deprecated Logger.init(category:)`.
- Explain the *why* in the PR description. The *what* is in the diff.
- If your change touches a protocol in `Infra*`, the PR must also update the corresponding `Mock*` in `InfraTestSupport`.

## Tests

The package uses Swift Testing (`import Testing`). XCTest is not used. Each testable module has its own test target under `Tests/`:

| Test target | Covers |
|---|---|
| `InfraCoreTests` | `LogManager`, `Logger` level and category mapping, `MaskStringConvertible`, `AppFileManager` |
| `InfraNetworkTests` | `DeviceCredentialsGenerator`, `NetworkRequestBuilder`, `URLRequest` / `URLComponents` extensions, models, `NetworkClient` via a `URLProtocol` stub |
| `InfraSearchTests` | `SearchService` ranking and ordering |
| `InfraUserDefaultsTests` | `UserDefaultsRepository` over an isolated suite, `UserDefaultsKey` |
| `InfraPdfTests` | `CertificateTemplateType`, `CertificateGeneratorFactory`, `CertificateData` |
| `InfraImageMetadataTests` | `ImageMetadataService` |
| `InfraTestSupportTests` | every `Mock*` in `InfraTestSupport` |

`InfraKeychain`, `InfraDatabase`, `InfraFileCache` and `InfraNotifications` have no test target yet. Each needs an injectable dependency before it can be tested without touching the system Keychain, Application Support, the network or the notification center.

Run the suite from Xcode with Product → Test (⌘U) on the `SwiftInfrastructure-Package` scheme, or from the shell:

```bash
xcodebuild test -scheme SwiftInfrastructure-Package -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Pick any installed simulator for `name=`. `swift test` on macOS is **not supported**, because the package declares iOS as its only platform.

Rules for new tests:

- Tests are hermetic. They never use the network, the system Keychain, `UserDefaults.standard` or files outside a temporary directory they create and remove.
- Tests are silent. Use `MockLogger` from `InfraTestSupport` instead of a real `Logger`, or construct `Logger` with both console and OS logging disabled.
- Tests are parallel-safe. Each test owns its system under test and backing store.
- A new protocol in an `Infra*` module ships with a `Mock*` in `InfraTestSupport` and tests for that mock in `InfraTestSupportTests`.

## Reporting issues

Open an issue at [https://github.com/IcemanEA/SwiftInfrastructure/issues](https://github.com/IcemanEA/SwiftInfrastructure/issues). Include:

- iOS version and Xcode version you're building against
- Which `Infra*` module(s) the issue relates to
- Minimal reproducer if possible — a few lines of Swift inside a standalone SPM package is ideal

## License

By contributing, you agree that your contribution will be licensed under the project's MIT license (see `LICENSE`).
