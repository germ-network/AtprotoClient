//
//  DidWebResolverTests.swift
//  AtprotoClientTests
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes
import Testing

import struct AtprotoClientMocks.StubHTTPFetcher

@testable import AtprotoClient

@Suite struct DidWebResolverURLConstructionTests {
	// MARK: - Happy path

	@Test func plainHostResolvesToTheWellKnownPath() throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let url = try Atproto.DidWebResolver.documentURL(for: did)
		#expect(url.absoluteString == "https://example.com/.well-known/did.json")
	}

	@Test func subdomainsAndHyphensAreAccepted() throws {
		let did = try Atproto.DID(string: "did:web:my-pds.example.co.uk")
		let url = try Atproto.DidWebResolver.documentURL(for: did)
		#expect(url.host == "my-pds.example.co.uk")
	}

	@Test func hostIsLowercased() throws {
		let did = try Atproto.DID(string: "did:web:Example.COM")
		let url = try Atproto.DidWebResolver.documentURL(for: did)
		#expect(url.host == "example.com")
	}

	// MARK: - Rejections that must throw, not silently resolve to something else

	@Test func wrongMethodThrows() throws {
		let did = try Atproto.DID(string: "did:plc:abc123")
		#expect(throws: Atproto.DidWebResolver.Errors.notDidWeb) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func theDidWebPathFormIsUnsupported() throws {
		// Matches the reference's UnsupportedDidWebPathError.
		let did = try Atproto.DID(string: "did:web:example.com:user:alice")
		#expect(throws: Atproto.DidWebResolver.Errors.unsupportedDidWebPath) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func aTrailingColonIsAlsoThePathForm() throws {
		// did:web:example.com: splits into ["example.com", ""] — two raw
		// segments, same rejection as a real path.
		let did = try Atproto.DID(string: "did:web:example.com:")
		#expect(throws: Atproto.DidWebResolver.Errors.unsupportedDidWebPath) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func emptyIdentifierIsRejected() throws {
		let did = Atproto.DID(method: .web, identifier: "")
		#expect(throws: Atproto.DidWebResolver.Errors.invalidHost) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func malformedPercentEncodingThrows() throws {
		// A lone `%` with no following hex pair.
		let did = Atproto.DID(method: .web, identifier: "example.com%")
		#expect(throws: Atproto.DidWebResolver.Errors.malformedPercentEncoding) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	// MARK: - The port-form: matches the reference's decode, then this
	// resolver deliberately refuses it (localhost/dev is out of scope).

	@Test func aPercentEncodedPortIsDecodedThenRejected() throws {
		// One raw segment (the colon is escaped), decodes to
		// "example.com:3000", then refused for containing a colon.
		let did = Atproto.DID(method: .web, identifier: "example.com%3A3000")
		#expect(throws: Atproto.DidWebResolver.Errors.invalidHost) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	// MARK: - Injection attempts a naive string-interpolated URL would have accepted

	@Test(arguments: [
		"example.com%2Fpath",  // encoded path separator
		"a%40evil.com",  // encoded @, userinfo injection
		"example.com%23fragment",  // encoded fragment
		"exa mple.com",  // literal space
		"example\u{0000}.com",  // NUL
		"[::1]",  // IPv6 bracket literal — colon rejected the same as a port
		"192.168.1.1",  // dotted IPv4 — last label all-digits
		"0177.0.0.1",  // octal IPv4 spelling
		"2130706433",  // decimal IPv4 spelling, single label
		"127。0.0.1",  // Unicode ideographic full stop as a confusable dot
		"xn--",  // a single punycode label with no TLD
	])
	func rejectedHostForms(_ identifier: String) throws {
		let did = Atproto.DID(method: .web, identifier: identifier)
		#expect(throws: (any Error).self) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test(arguments: [
		"localhost",
		"foo.localhost",
		"example.internal",
		"example.local",
		"example.test",
		"example.invalid",
		"example.example",
		"example.onion",
	])
	func reservedAndLoopbackHostsAreRejected(_ identifier: String) throws {
		let did = Atproto.DID(method: .web, identifier: identifier)
		#expect(throws: Atproto.DidWebResolver.Errors.invalidHost) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func uppercaseReservedTLDsAreStillRejected() throws {
		// Distinct from hostIsLowercased(), which only checks the built URL —
		// this checks that validation itself saw the lowercased form.
		let did = try Atproto.DID(string: "did:web:FOO.LOCALHOST")
		#expect(throws: Atproto.DidWebResolver.Errors.invalidHost) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func aHostOverTheRFC1035LengthLimitIsRejected() throws {
		let label = String(repeating: "a", count: 63)
		let identifier = Array(repeating: label, count: 5).joined(separator: ".")
		#expect(identifier.count > 253)
		let did = Atproto.DID(method: .web, identifier: identifier)
		#expect(throws: Atproto.DidWebResolver.Errors.invalidHost) {
			try Atproto.DidWebResolver.documentURL(for: did)
		}
	}

	@Test func punycodeEncodedInternationalDomainsAreAccepted() throws {
		// xn--... is a normal RFC 1123 label — a real IDN must already be
		// punycode before it reaches this resolver.
		let did = try Atproto.DID(string: "did:web:xn--nxasmq6b.example.com")
		let url = try Atproto.DidWebResolver.documentURL(for: did)
		#expect(url.host == "xn--nxasmq6b.example.com")
	}
}

@Suite struct DidWebResolverFetchTests {
	private func envelope(status: HTTPResponse.Status, body: Data) -> HTTPDataResponse {
		.init(data: body, response: .init(status: status))
	}

	@Test func sendsTheExactReferenceAcceptHeader() async throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let fetcher = StubHTTPFetcher { request in
			#expect(
				request.request.headerFields[.accept]
					== "application/did+ld+json,application/json"
			)
			return .init(
				data: try JSONEncoder().encode(MinimalDocument(id: did.rawValue)),
				response: .init(status: .ok)
			)
		}
		_ = try await Atproto.DidWebResolver(fetcher: fetcher).resolve(did: did)
	}

	@Test func aNotFoundResponseResolvesToNil() async throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let fetcher = StubHTTPFetcher(envelope(status: .notFound, body: Data()))
		let document = try await Atproto.DidWebResolver(fetcher: fetcher).resolve(did: did)
		#expect(document == nil)
	}

	@Test(arguments: [HTTPResponse.Status.movedPermanently, .found, .temporaryRedirect])
	func aRedirectThrowsRatherThanResolvingToNilOrFollowing(
		_ status: HTTPResponse.Status
	) async throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let fetcher = StubHTTPFetcher(envelope(status: status, body: Data()))
		await #expect(throws: Atproto.DidWebResolver.Errors.redirectRefused) {
			try await Atproto.DidWebResolver(fetcher: fetcher).resolve(did: did)
		}
	}

	@Test func aDocumentIdMismatchThrows() async throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let fetcher = StubHTTPFetcher(
			.init(
				data: try JSONEncoder().encode(
					MinimalDocument(id: "did:web:someone-else.com")
				),
				response: .init(status: .ok)
			)
		)
		await #expect(
			throws: Atproto.DidWebResolver.Errors.documentIdMismatch(
				requested: did.rawValue,
				returned: "did:web:someone-else.com"
			)
		) {
			try await Atproto.DidWebResolver(fetcher: fetcher).resolve(did: did)
		}
	}

	@Test func matchingDocumentIdResolves() async throws {
		let did = try Atproto.DID(string: "did:web:example.com")
		let fetcher = StubHTTPFetcher(
			.init(
				data: try JSONEncoder().encode(MinimalDocument(id: did.rawValue)),
				response: .init(status: .ok)
			)
		)
		let document = try await Atproto.DidWebResolver(fetcher: fetcher).resolve(did: did)
		#expect(document?.id == did.rawValue)
	}

	/// Pins current decode strictness rather than fixing it — see GER-2274.
	/// A real did:web document may omit `verificationMethod`/`service` and
	/// carry `@context` as a bare string; `Atproto.DIDDocument` requires all
	/// three.
	@Test func aMinimalRealWorldDidWebDocumentFailsToDecodeUnderTodaysStrictness() throws {
		let json = Data(
			"""
			{"@context": "https://www.w3.org/ns/did/v1", "id": "did:web:example.com"}
			""".utf8
		)
		#expect(throws: (any Error).self) {
			try json.decode() as Atproto.DIDDocument
		}
	}
}

/// The smallest body `Atproto.DIDDocument`'s current decoder accepts.
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
