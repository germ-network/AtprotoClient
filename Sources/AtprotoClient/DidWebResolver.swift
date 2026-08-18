//
//  DidWebResolver.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

extension Atproto {
	/// Resolves a did:web identifier by fetching
	/// `https://{host}/.well-known/did.json`.
	///
	/// Matches `@atproto/identity`'s `web-resolver.ts` — same Accept header,
	/// redirect refusal, single-segment restriction — except it refuses
	/// `localhost` and any host that isn't a public hostname (GER-1912:
	/// did:web identifiers are attacker-influenced input turned into a fetch
	/// URL, which the reference has no reason to screen for and this does).
	public struct DidWebResolver: Sendable {
		static let wellKnownPath = "/.well-known/did.json"
		static let acceptHeader = "application/did+ld+json,application/json"

		let fetcher: any HTTPFetcher

		/// Defaults to a redirect-refusing session — do not override with a
		/// redirect-following fetcher in production. Host screening runs once,
		/// before the request; a followed redirect bypasses it, and nothing
		/// downstream can detect that after the fact.
		public init(fetcher: any HTTPFetcher = URLSession.manualRedirect()) {
			self.fetcher = fetcher
		}

		/// `nil` for a well-formed request the endpoint declined; throws for
		/// anything that means this resolver or the document can't be trusted.
		public func resolve(did: Atproto.DID) async throws -> Atproto.DIDDocument? {
			let url = try Self.documentURL(for: did)

			let request = try BundledHTTPRequest(
				url: url,
				headerFields: [.accept: Self.acceptHeader]
			)
			let response = try await fetcher.data(for: request)

			if response.response.status.kind == .redirection {
				// A refused redirect surfaces as its own response rather than
				// being followed — distinct from an ordinary 4xx/5xx.
				throw Errors.redirectRefused
			}
			guard response.response.status.kind == .successful else {
				return nil
			}

			let document: Atproto.DIDDocument = try response.data.decode()
			// Resolver.swift's own contract, unenforced elsewhere in this
			// ecosystem today — see GER-2274.
			guard document.id == did.rawValue else {
				throw Errors.documentIdMismatch(
					requested: did.rawValue,
					returned: document.id
				)
			}
			return document
		}

		/// Pure and synchronous — every security-relevant decision here is
		/// testable without a network call or a mock.
		static func documentURL(for did: Atproto.DID) throws -> URL {
			guard did.method == .web else { throw Errors.notDidWeb }

			// Split on the raw (undecoded) identifier — an encoded %3A isn't
			// a separator, matching the reference.
			let rawParts = did.identifier.split(
				separator: ":",
				omittingEmptySubsequences: false
			)
			guard rawParts.count == 1, let rawHost = rawParts.first else {
				// The path form (did:web:host:user:alice) is unsupported,
				// matching the reference's UnsupportedDidWebPathError.
				throw Errors.unsupportedDidWebPath
			}

			guard let decoded = String(rawHost).removingPercentEncoding else {
				// Matches decodeURIComponent's throw on a malformed escape.
				throw Errors.malformedPercentEncoding
			}

			// Normalized once — used for both validation and the URL.
			let host = decoded.lowercased()
			try validate(host: host)

			var components = URLComponents()
			components.scheme = "https"
			components.host = host
			components.path = Self.wellKnownPath
			guard let url = components.url else {
				throw Errors.invalidHost
			}
			return url
		}

		/// A hostname allowlist, not a character blocklist — did:web is
		/// spec-defined hostname-only, so every IPv4/IPv6 spelling is excluded
		/// by construction (none ends in two alphabetic labels), without
		/// needing AtprotoTypes' unreleased `Service.validate`.
		///
		/// `host` must already be lowercased by the caller.
		static func validate(host: String) throws {
			// No ports, no IPv6 literals — see the type doc comment on why
			// localhost/dev is out of scope entirely.
			guard !host.contains(":") else { throw Errors.invalidHost }
			// RFC 1035's overall bound, not just the per-label one below.
			guard host.count <= 253 else { throw Errors.invalidHost }

			let labels = host.split(
				separator: ".",
				omittingEmptySubsequences: false
			)
			guard labels.count >= 2 else { throw Errors.invalidHost }
			guard labels.allSatisfy(isValidLabel) else { throw Errors.invalidHost }

			// No public TLD is all-digits, which rules out every IPv4
			// spelling without parsing any of them as a number.
			let tld = labels[labels.count - 1]
			guard tld.contains(where: { !$0.isNumber }) else {
				throw Errors.invalidHost
			}

			guard !Self.reservedTLDs.contains(tld) else { throw Errors.invalidHost }
		}

		/// RFC 1123 label grammar. Explicit checks rather than a regex — this
		/// is the security-critical predicate in the file.
		private static func isValidLabel(_ label: Substring) -> Bool {
			guard !label.isEmpty, label.count <= 63 else { return false }
			guard let first = label.first, isAlphanumericASCII(first) else {
				return false
			}
			guard let last = label.last, isAlphanumericASCII(last) else {
				return false
			}
			return label.allSatisfy { isAlphanumericASCII($0) || $0 == "-" }
		}

		private static func isAlphanumericASCII(_ char: Character) -> Bool {
			char.isASCII && (char.isLetter || char.isNumber)
		}

		/// IANA special-use domain names (RFC 6761) — never a legitimate
		/// public identity.
		static let reservedTLDs: Set<Substring> = [
			"localhost", "local", "internal", "invalid", "test", "example",
			"onion",
		]
	}
}

extension Atproto.DidWebResolver {
	public enum Errors: Error, Equatable, Sendable {
		case notDidWeb
		case unsupportedDidWebPath
		case malformedPercentEncoding
		case invalidHost
		case redirectRefused
		case documentIdMismatch(requested: String, returned: String)
	}
}

extension Atproto.DidWebResolver.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .notDidWeb: "DID is not a did:web identifier"
		case .unsupportedDidWebPath: "did:web path form is not supported"
		case .malformedPercentEncoding:
			"did:web identifier has malformed percent-encoding"
		case .invalidHost: "did:web identifier does not resolve to a valid public host"
		case .redirectRefused: "the did:web endpoint attempted a redirect, which is refused"
		case .documentIdMismatch(let requested, let returned):
			"resolved document id \"\(returned)\" does not match requested DID \"\(requested)\""
		}
	}
}
