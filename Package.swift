// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "AtprotoClient",
	platforms: [.iOS(.v16), .macOS(.v15)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "AtprotoClient",
			targets: ["AtprotoClient"],
		),
		.library(name: "AtprotoClientMocks", targets: ["AtprotoClientMocks"]),
	],
	dependencies: [
		.package(
			url: "https://github.com/germ-network/AtprotoTypes.git",
			// Temporary revision pin to the swift-crypto-5 commit
			// (germ-network/AtprotoTypes#69); replace with the released version
			// once it cuts.
			revision: "8e00dd81013fef864de2b0f3dde7ad7fcbdc119b"
		),
		.package(
			url: "https://github.com/germ-network/GermConvenience.git",
			// 0.10.0 is its swift-crypto-5 release — the revision pin drops.
			from: "0.10.0"
		),
		.package(
			url: "https://github.com/apple/swift-crypto.git",
			from: "5.0.0"),
		.package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "AtprotoClient",
			dependencies: [
				"AtprotoTypes",
				.product(name: "Crypto", package: "swift-crypto"),
				"GermConvenience",
				.product(name: "GermConvenienceHTTP", package: "GermConvenience"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "Logging", package: "swift-log"),
			]
		),
		.target(
			name: "AtprotoClientMocks",
			dependencies: [
				"AtprotoClient",
				.product(name: "AtprotoTypesMocks", package: "AtprotoTypes"),
				"GermConvenience",
				.product(name: "GermConvenienceHTTP", package: "GermConvenience"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "Mockable", package: "AtprotoTypes"),
			]
		),
		.testTarget(
			name: "AtprotoClientTests",
			dependencies: [
				"AtprotoClient", "AtprotoClientMocks",
				.product(name: "GermConvenienceHTTP", package: "GermConvenience"),
			]
		),
	]
)
