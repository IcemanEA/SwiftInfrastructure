// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "SwiftInfrastructure",
	platforms: [
		.iOS(.v15)
	],
	products: [
		.library(name: "InfraCore",          targets: ["InfraCore"]),
		.library(name: "InfraDatabase",      targets: ["InfraDatabase"]),
		.library(name: "InfraNetwork",       targets: ["InfraNetwork"]),
		.library(name: "InfraKeychain",      targets: ["InfraKeychain"]),
		.library(name: "InfraUserDefaults",  targets: ["InfraUserDefaults"]),
		.library(name: "InfraNotifications", targets: ["InfraNotifications"]),
		.library(name: "InfraPdf",           targets: ["InfraPdf"]),
		.library(name: "InfraFileCache",     targets: ["InfraFileCache"]),
		.library(name: "InfraImageMetadata", targets: ["InfraImageMetadata"]),
		.library(name: "InfraSearch",        targets: ["InfraSearch"]),
		.library(name: "InfraTestSupport",   targets: ["InfraTestSupport"])
	],
	dependencies: [
		.package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.7.1"))
	],
	targets: [
		.target(name: "InfraCore"),
		.target(
			name: "InfraDatabase",
			dependencies: [
				"InfraCore",
				.product(name: "GRDB", package: "GRDB.swift")
			]
		),
		.target(name: "InfraNetwork",       dependencies: ["InfraCore"]),
		.target(name: "InfraFileCache",     dependencies: ["InfraCore"]),
		.target(name: "InfraNotifications", dependencies: ["InfraCore"]),
		.target(name: "InfraKeychain",      dependencies: ["InfraCore"]),
		.target(name: "InfraUserDefaults"),
		.target(name: "InfraPdf"),
		.target(name: "InfraImageMetadata"),
		.target(name: "InfraSearch"),
		.target(
			name: "InfraTestSupport",
			dependencies: [
				"InfraCore",
				"InfraDatabase",
				"InfraNetwork",
				"InfraKeychain",
				"InfraUserDefaults",
				"InfraNotifications",
				"InfraPdf",
				"InfraFileCache",
				"InfraImageMetadata",
				"InfraSearch"
			]
		)
	],
	swiftLanguageModes: [.v5]
)
