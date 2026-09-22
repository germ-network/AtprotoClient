//
//  WellKnownHandleResolverTests.swift
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

@Suite struct WellKnownHandleResolverURLConstructionTests {
	@Test func buildsTheWellKnownAtprotoDidURL() throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let url = try Atproto.WellKnownHandleResolver.wellKnownURL(for: handle)
		#expect(url.absoluteString == "https://alice.example.com/.well-known/atproto-did")
	}

	@Test func usesHTTPS() throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let url = try Atproto.WellKnownHandleResolver.wellKnownURL(for: handle)
		#expect(url.scheme == "https")
	}
}

@Suite struct WellKnownHandleResolverFetchTests {
	private func envelope(status: HTTPResponse.Status, body: Data) -> HTTPDataResponse {
		.init(data: body, response: .init(status: status))
	}

	@Test func sendsThePlainTextAcceptHeader() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher { request in
			#expect(request.request.headerFields[.accept] == "text/plain;charset=UTF-8")
			return .init(
				data: Data("did:plc:abc123456789012345678ab".utf8),
				response: .init(status: .ok)
			)
		}
		_ = try await Atproto.WellKnownHandleResolver(fetcher: fetcher).resolve(
			handle: handle)
	}

	@Test func aSuccessfulPlainDidBodyResolves() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(
			envelope(status: .ok, body: Data("did:plc:abc123456789012345678ab".utf8))
		)
		let did = try await Atproto.WellKnownHandleResolver(fetcher: fetcher)
			.resolve(handle: handle)
		#expect(did == Atproto.DID(method: .plc, identifier: "abc123456789012345678ab"))
	}

	@Test func trailingWhitespaceAndNewlinesAreTrimmed() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(
			envelope(status: .ok, body: Data("did:plc:abc123456789012345678ab\n".utf8))
		)
		let did = try await Atproto.WellKnownHandleResolver(fetcher: fetcher)
			.resolve(handle: handle)
		#expect(did == Atproto.DID(method: .plc, identifier: "abc123456789012345678ab"))
	}

	@Test func aNotFoundResponseResolvesToNil() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(envelope(status: .notFound, body: Data()))
		let did = try await Atproto.WellKnownHandleResolver(fetcher: fetcher)
			.resolve(handle: handle)
		#expect(did == nil)
	}

	@Test func aSuccessfulButEmptyBodyResolvesToNil() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(envelope(status: .ok, body: Data()))
		let did = try await Atproto.WellKnownHandleResolver(fetcher: fetcher)
			.resolve(handle: handle)
		#expect(did == nil)
	}

	@Test(arguments: [HTTPResponse.Status.movedPermanently, .found, .temporaryRedirect])
	func aRedirectThrowsRatherThanResolvingToNilOrFollowing(
		_ status: HTTPResponse.Status
	) async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(envelope(status: status, body: Data()))
		await #expect(throws: Atproto.WellKnownHandleResolver.Errors.redirectRefused) {
			try await Atproto.WellKnownHandleResolver(fetcher: fetcher).resolve(
				handle: handle)
		}
	}

	@Test func anOversizedBodyIsRejectedBeforeParsing() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let oversized = Data(repeating: UInt8(ascii: "a"), count: 9000)
		let fetcher = StubHTTPFetcher(envelope(status: .ok, body: oversized))
		await #expect(throws: Atproto.WellKnownHandleResolver.Errors.responseTooLarge) {
			try await Atproto.WellKnownHandleResolver(fetcher: fetcher).resolve(
				handle: handle)
		}
	}

	@Test func aMalformedDidBodyThrows() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(
			envelope(status: .ok, body: Data("not-a-did".utf8))
		)
		await #expect(throws: (any Error).self) {
			try await Atproto.WellKnownHandleResolver(fetcher: fetcher).resolve(
				handle: handle)
		}
	}

	@Test func onlyTheFirstLineOfTheBodyIsParsed() async throws {
		let handle = try Atproto.Handle(string: "alice.example.com")
		let fetcher = StubHTTPFetcher(
			envelope(
				status: .ok,
				body: Data(
					"did:plc:abc123456789012345678ab\nunexpected trailer".utf8)
			)
		)
		let did = try await Atproto.WellKnownHandleResolver(fetcher: fetcher)
			.resolve(handle: handle)
		#expect(did == Atproto.DID(method: .plc, identifier: "abc123456789012345678ab"))
	}
}
