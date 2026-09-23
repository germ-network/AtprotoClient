//
//  BskyProfileIfExistsTests.swift
//  AtprotoClientTests
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP
import HTTPTypes
import Testing

import struct AtprotoClientMocks.StubHTTPFetcher

@testable import AtprotoClient

@Suite struct BskyProfileIfExistsTests {
	private let appViewURL = URL(string: "https://appview.example.com")!
	private let actor: LexiconString.AtIdentifier

	init() throws {
		actor = .handle(try Atproto.Handle(string: "nobody.example.com"))
	}

	private func agent(fetcher: HTTPFetcher) throws -> BskyAppViewAgent {
		try BskyAppViewAgent(serviceUrl: appViewURL, resourceFetcher: fetcher)
	}

	/// `getProfile` declares no errors of its own - confirms the live
	/// AppView's actual miss shape parses as a typed `.xrpcError` (rather
	/// than falling through to `.unrecognized`) with the message intact,
	/// which is what `bskyProfileIfExists` pattern-matches against.
	@Test(
		"GetProfile.badRequestErrors recognizes InvalidRequest, so the real parser produces .xrpcError"
	)
	func realParserProducesXrpcErrorWithMessageIntact() async throws {
		#expect(
			Lexicon.App.Bsky.Actor.GetProfile.badRequestErrors.contains(
				"InvalidRequest"))

		let fetcher = StubHTTPFetcher(
			.init(
				data: Data(
					"{\"error\":\"InvalidRequest\",\"message\":\"Profile not found\"}"
						.utf8),
				response: .init(status: .badRequest)))

		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await self.agent(fetcher: fetcher).bskyProfile(actor: actor)
		}
		guard case .xrpcError(let status, let error) = thrown else {
			Issue.record("expected .xrpcError, got \(String(describing: thrown))")
			return
		}
		#expect(status == .badRequest)
		#expect(error.error == "InvalidRequest")
		#expect(error.message == "Profile not found")
	}

	@Test("The exact not-found shape (400 InvalidRequest 'Profile not found') maps to nil")
	func exactNotFoundShapeMapsToNil() async throws {
		let fetcher = StubHTTPFetcher(
			.init(
				data: Data(
					"{\"error\":\"InvalidRequest\",\"message\":\"Profile not found\"}"
						.utf8),
				response: .init(status: .badRequest)))

		let profile = try await agent(fetcher: fetcher).bskyProfileIfExists(actor: actor)

		#expect(profile == nil)
	}

	@Test("A 400 InvalidRequest with a different message rethrows rather than mapping to nil")
	func differentMessageRethrows() async throws {
		let fetcher = StubHTTPFetcher(
			.init(
				data: Data(
					"{\"error\":\"InvalidRequest\",\"message\":\"Something else\"}"
						.utf8),
				response: .init(status: .badRequest)))

		await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await self.agent(fetcher: fetcher).bskyProfileIfExists(
				actor: self.actor)
		}
	}

	@Test("A 200 response returns the profile")
	func successReturnsProfile() async throws {
		let fetcher = StubHTTPFetcher(
			.init(
				data: Data(
					"""
					{"did":"did:plc:aaaaaaaaaaaaaaaaaaaaaaaa","handle":"alice.example.com","displayName":"Alice"}
					""".utf8),
				response: .init(status: .ok)))

		let profile = try await agent(fetcher: fetcher).bskyProfileIfExists(actor: actor)

		#expect(profile?.handle.rawValue == "alice.example.com")
		#expect(profile?.displayName == "Alice")
	}
}
