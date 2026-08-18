//
//  DidPlcResolverTests.swift
//  AtprotoClientTests
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes
import Testing

import struct AtprotoClientMocks.StubHTTPFetcher

@testable import AtprotoClient

@Suite struct DidPlcResolverURLConstructionTests {
	static let validIdentifier = "yk4dd2qkboz2yv6tpubpc6co"

	// MARK: - Happy path

	@Test func aValidIdentifierResolvesToTheDirectoryPath() throws {
		let did = try Atproto.DID(string: "did:plc:\(Self.validIdentifier)")
		let url = try Atproto.DidPlcResolver.documentURL(
			for: did, directory: Atproto.DidPlcResolver.defaultDirectory)
		#expect(
			url.absoluteString
				== "https://plc.directory/did:plc:\(Self.validIdentifier)")
	}

	@Test func aCustomDirectoryIsHonored() throws {
		let did = try Atproto.DID(string: "did:plc:\(Self.validIdentifier)")
		let url = try Atproto.DidPlcResolver.documentURL(
			for: did, directory: URL(string: "https://plc.example.com")!)
		#expect(
			url.absoluteString
				== "https://plc.example.com/did:plc:\(Self.validIdentifier)")
	}

	// MARK: - Rejections that must throw, not silently resolve to something else

	@Test func wrongMethodThrows() throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		#expect(throws: Atproto.DidPlcResolver.Errors.notDidPlc) {
			try Atproto.DidPlcResolver.documentURL(
				for: did, directory: Atproto.DidPlcResolver.defaultDirectory)
		}
	}

	@Test(arguments: [
		"", "short", String(repeating: "a", count: 23), String(repeating: "a", count: 25),
	])
	func wrongLengthIdentifiersAreRejected(_ identifier: String) throws {
		let did = Atproto.DID(method: .plc, identifier: identifier)
		#expect(throws: Atproto.DidPlcResolver.Errors.invalidIdentifier) {
			try Atproto.DidPlcResolver.documentURL(
				for: did, directory: Atproto.DidPlcResolver.defaultDirectory)
		}
	}

	// MARK: - Injection attempts a naive string-interpolated URL would have accepted

	@Test(arguments: [
		"../../../../../../../etc/passwd",  // path traversal, wrong length anyway
		"aaaaaaaaaaaaaaaaaaaaaaa/",  // trailing path separator, 24 chars total
		"aaaaaaaaaaaaaaaaaaaaaaa.",  // trailing dot
		"aaaaaaaaaaaaaaaaaaaaaa%2",  // partial percent-encoding
		"aaaaaaaaaaaaaaaaaaaaaaa#",  // fragment
		"aaaaaaaaaaaaaaaaaaaaaaa?",  // query
		"aaaaaaaaaaaaaaaaaaaaaaa@",  // userinfo
		"aaaaaaaaaaaaaaaaaaaaaaa ",  // trailing space
		"AAAAAAAAAAAAAAAAAAAAAAAA",  // uppercase — base32 here is lowercase-only
		"aaaaaaaaaaaaaaaaaaaaaa01",  // 0 and 1 aren't in did:plc's base32 alphabet
		"aaaaaaaaaaaaaaaaaaaaaa89",  // neither are 8 and 9
	])
	func rejectedIdentifierForms(_ identifier: String) throws {
		let did = Atproto.DID(method: .plc, identifier: identifier)
		#expect(throws: Atproto.DidPlcResolver.Errors.invalidIdentifier) {
			try Atproto.DidPlcResolver.documentURL(
				for: did, directory: Atproto.DidPlcResolver.defaultDirectory)
		}
	}

	/// The load-bearing assertion for the injection cases above: confirm the
	/// built URL's host and path are exactly what was asked for, not just
	/// that *some* URL came back. The directory host is fixed and the path is
	/// attacker-influenced, which is the opposite shape from `DidWebResolver`
	/// (where the host is the attacker-influenced part) — this is where the
	/// test pressure belongs here.
	@Test func theBuiltURLNeverCarriesMoreThanTheValidatedIdentifier() throws {
		let did = try Atproto.DID(string: "did:plc:\(Self.validIdentifier)")
		let url = try Atproto.DidPlcResolver.documentURL(
			for: did, directory: Atproto.DidPlcResolver.defaultDirectory)
		#expect(url.host == "plc.directory")
		#expect(url.path == "/did:plc:\(Self.validIdentifier)")
	}
}

@Suite struct DidPlcResolverFetchTests {
	private func envelope(status: HTTPResponse.Status, body: Data) -> HTTPDataResponse {
		.init(data: body, response: .init(status: status))
	}

	@Test func initRejectsANonHttpsDirectory() throws {
		#expect(throws: Atproto.DidPlcResolver.Errors.invalidDirectory) {
			try Atproto.DidPlcResolver(
				directory: URL(string: "http://plc.directory")!,
				fetcher: StubHTTPFetcher(
					.init(data: Data(), response: .init(status: .ok)))
			)
		}
	}

	/// A trailing slash looks harmless but isn't: `documentURL` appends the
	/// DID directly onto the directory's path, so `https://plc.directory/`
	/// would build `https://plc.directory//did:plc:...` — a URL the real
	/// server 404s, making every resolution look like "DID not found" instead
	/// of "misconfigured directory." Caught at `init` instead.
	@Test(arguments: [
		"https://plc.directory/",
		"https://plc.directory/v1",
		"https://plc.directory?x=1",
		"https://plc.directory#frag",
		"https://user@plc.directory",
	])
	func initRejectsADirectoryThatIsNotABareOrigin(_ directoryString: String) throws {
		#expect(throws: Atproto.DidPlcResolver.Errors.invalidDirectory) {
			try Atproto.DidPlcResolver(
				directory: URL(string: directoryString)!,
				fetcher: StubHTTPFetcher(
					.init(data: Data(), response: .init(status: .ok)))
			)
		}
	}

	@Test func sendsTheExactAcceptHeaderAndRequestedUrl() async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher { request in
			#expect(
				request.request.headerFields[.accept]
					== "application/did+ld+json,application/json"
			)
			#expect(
				request.request.url?.absoluteString
					== "https://plc.directory/\(did.rawValue)"
			)
			return .init(
				data: try JSONEncoder().encode(MinimalDocument(id: did.rawValue)),
				response: .init(status: .ok)
			)
		}
		_ = try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
	}

	@Test func aNotFoundResponseResolvesToNil() async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher(envelope(status: .notFound, body: Data()))
		let document = try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
		#expect(document == nil)
	}

	/// A tombstoned DID — plc.directory answers `410` for a deactivated
	/// identity — resolves the same as any other declined request rather
	/// than getting a distinct case. "Gone" and "never existed" aren't
	/// distinguished today.
	@Test func aGoneResponseResolvesToNilTheSameAsNotFound() async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher(envelope(status: .gone, body: Data()))
		let document = try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
		#expect(document == nil)
	}

	@Test(arguments: [HTTPResponse.Status.movedPermanently, .found, .temporaryRedirect])
	func aRedirectThrowsRatherThanResolvingToNilOrFollowing(
		_ status: HTTPResponse.Status
	) async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher(envelope(status: status, body: Data()))
		await #expect(throws: Atproto.DidPlcResolver.Errors.redirectRefused) {
			try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
		}
	}

	@Test func aDocumentIdMismatchThrows() async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher(
			.init(
				data: try JSONEncoder().encode(
					MinimalDocument(id: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")
				),
				response: .init(status: .ok)
			)
		)
		await #expect(
			throws: Atproto.DidPlcResolver.Errors.documentIdMismatch(
				requested: did.rawValue,
				returned: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
			)
		) {
			try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
		}
	}

	@Test func matchingDocumentIdResolves() async throws {
		let did = try Atproto.DID(
			string: "did:plc:\(DidPlcResolverURLConstructionTests.validIdentifier)")
		let fetcher = StubHTTPFetcher(
			.init(
				data: try JSONEncoder().encode(MinimalDocument(id: did.rawValue)),
				response: .init(status: .ok)
			)
		)
		let document = try await Atproto.DidPlcResolver(fetcher: fetcher).resolve(did: did)
		#expect(document?.id == did.rawValue)
	}
}

/// The smallest body `Atproto.DIDDocument`'s current decoder accepts —
/// duplicated from `DidWebResolverTests.swift` rather than shared, since
/// both are file-private and this repo has no shared test-support target.
private struct MinimalDocument: Encodable {
	let context: [String] = []
	let id: String
	let alsoKnownAs: [String]? = nil
	let verificationMethod: [Empty] = []
	let service: [Empty] = []

	enum CodingKeys: String, CodingKey {
		case context = "@context"
		case id, alsoKnownAs, verificationMethod, service
	}

	struct Empty: Encodable {}
}
