//
//  DnsHandleResolverTests.swift
//  AtprotoClientTests
//
//  Exercises DnsHandleResolver's did= filtering against an injected
//  DNSTXTFetcher, so these tests don't touch the network or DoHTXTFetcher -
//  that conformer is covered directly in DoHTXTFetcherTests.
//

import AtprotoTypes
import Foundation
import Testing

@testable import AtprotoClient

private final class MockTXTFetcher: DNSTXTFetcher, @unchecked Sendable {
	let records: [String]
	private(set) var requestedName: String?

	init(records: [String]) {
		self.records = records
	}

	func txtRecords(name: String) async throws -> [String] {
		requestedName = name
		return records
	}
}

struct DnsHandleResolverTests {
	@Test func queriesTheUnderscoreAtprotoPrefixedName() async throws {
		let mock = MockTXTFetcher(records: [])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		_ = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(mock.requestedName == "_atproto.alice.example.com")
	}

	@Test func parsesTheDidFromAMatchingRecord() async throws {
		let mock = MockTXTFetcher(records: ["did=did:plc:abc123"])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		let did = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(did == Atproto.DID(method: .plc, identifier: "abc123"))
	}

	@Test func parsesEverythingAfterTheFirstEqualsSignAsTheDid() async throws {
		// a naive split(separator: "=").last would truncate this at the
		// second "=" instead of taking everything after "did="
		let mock = MockTXTFetcher(records: ["did=did:web:a=b"])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		let did = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(did == Atproto.DID(method: .web, identifier: "a=b"))
	}

	@Test func picksTheFirstMatchingRecordAmongSeveral() async throws {
		let mock = MockTXTFetcher(records: [
			"v=spf1 -all",
			"did=did:plc:first",
			"did=did:plc:second",
		])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		let did = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(did == Atproto.DID(method: .plc, identifier: "first"))
	}

	@Test func returnsNilWhenNoRecordHasTheDidPrefix() async throws {
		let mock = MockTXTFetcher(records: ["v=spf1 -all", "some other txt record"])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		let did = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(did == nil)
	}

	@Test func returnsNilForAnEmptyRecordSet() async throws {
		let mock = MockTXTFetcher(records: [])
		let resolver = Atproto.DnsHandleResolver(txtFetcher: mock)

		let did = try await resolver.resolve(
			handle: try Atproto.Handle(string: "alice.example.com"))

		#expect(did == nil)
	}

	@Test func propagatesAThrowFromTheFetcher() async throws {
		struct Boom: Error {}
		struct ThrowingFetcher: DNSTXTFetcher {
			func txtRecords(name: String) async throws -> [String] { throw Boom() }
		}
		let resolver = Atproto.DnsHandleResolver(txtFetcher: ThrowingFetcher())

		await #expect(throws: Boom.self) {
			try await resolver.resolve(
				handle: try Atproto.Handle(string: "alice.example.com"))
		}
	}
}
