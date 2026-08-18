//
//  DidWebResolver.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

extension Atproto {
	/// Resolves a did:web identifier to its DID document by fetching
	/// `https://{host}/.well-known/did.json`.
	///
	/// Matches `@atproto/identity`'s `web-resolver.ts` (bluesky-social/atproto)
	/// deliberately, not by convention: same Accept header, same redirect
	/// refusal, same single-segment restriction. Two departures, both
	/// tightening rather than loosening:
	///
	/// - The reference downgrades to `http://` for a `localhost` host, for
	///   local development. This resolver refuses `localhost` — along with
	///   every other host that isn't a normal two-label-or-more public
	///   hostname — outright. A did:web identity has no legitimate reason to
	///   be a loopback address in production, and a dev carve-out is a small,
	///   additive, non-breaking change to make later if one is ever actually
	///   needed — not something to build speculatively now.
	/// - did:web identifiers are attacker-influenced input turned directly
	///   into a fetch URL (Linear GER-1912), so the resolved host is screened
	///   against a strict hostname grammar before any request is made. The
	///   reference does no such screening — it doesn't need to, since a
	///   browser or Node process fetching on a user's behalf has different
	///   risk properties than a server-side resolver fetching on an
	///   attacker-chosen host.
	public struct DidWebResolver: Sendable {
		static let wellKnownPath = "/.well-known/did.json"
		static let acceptHeader = "application/did+ld+json,application/json"

		let fetcher: any HTTPFetcher

		/// Defaults to a redirect-refusing session. **Do not override this with
		/// a redirect-following fetcher in production.** The host screening
		/// below runs exactly once, on the constructed URL, before the
		/// request — a followed redirect bypasses it completely, and nothing
		/// downstream can detect after the fact that a redirect happened
		/// (`HTTPDataResponse` carries no final URL). Fetcher injection exists
		/// for tests, via a canned `HTTPFetcher` from `AtprotoClientMocks`, not
		/// for callers that want redirects honoured.
		public init(fetcher: any HTTPFetcher = URLSession.manualRedirect()) {
			self.fetcher = fetcher
		}

		/// `nil` for a well-formed request the endpoint declined (any non-2xx
		/// other than a redirect); throws for everything that indicates this
		/// resolver, or the document it got back, cannot be trusted.
		public func resolve(did: Atproto.DID) async throws -> Atproto.DIDDocument? {
			let url = try Self.documentURL(for: did)

			let request = try BundledHTTPRequest(
				url: url,
				headerFields: [.accept: Self.acceptHeader]
			)
			let response = try await fetcher.data(for: request)

			if response.response.status.kind == .redirection {
				// A redirect-refusing fetcher surfaces the refused redirect as
				// its own response instead of silently following it — this is
				// that refusal, not an ordinary failed fetch. Distinguished
				// from a plain 4xx/5xx because it is the one signal available
				// that something tried to redirect this request at all.
				throw Errors.redirectRefused
			}
			guard response.response.status.kind == .successful else {
				return nil
			}

			let document: Atproto.DIDDocument = try response.data.decode()
			// The contract `Resolver.swift` already documents ("must always
			// compare the did to the returned document's id and throw if
			// mismatched") but that nothing in this ecosystem currently
			// performs — see GER-2274.
			guard document.id == did.rawValue else {
				throw Errors.documentIdMismatch(
					requested: did.rawValue,
					returned: document.id
				)
			}
			return document
		}

		/// Pure and synchronous — every security-relevant decision here is
		/// exhaustively testable without a network call or a mock.
		static func documentURL(for did: Atproto.DID) throws -> URL {
			guard did.method == .web else { throw Errors.notDidWeb }

			// did:web's identifier is colon-separated; splitting on the RAW
			// (not yet percent-decoded) string matches the reference exactly —
			// an encoded %3A does not count as a path separator here, only a
			// literal `:` does.
			let rawParts = did.identifier.split(
				separator: ":",
				omittingEmptySubsequences: false
			)
			guard rawParts.count == 1, let rawHost = rawParts.first else {
				// did:web's path form (did:web:example.com:user:alice) is real
				// per the method spec but unsupported here, matching the
				// reference's own UnsupportedDidWebPathError — atproto
				// identities are never path-form in practice.
				throw Errors.unsupportedDidWebPath
			}

			guard let decoded = String(rawHost).removingPercentEncoding else {
				// Matches JS decodeURIComponent, which throws on a malformed
				// escape rather than passing the raw bytes through.
				throw Errors.malformedPercentEncoding
			}

			// Lowercased once, here — used for both validation and the
			// constructed URL, so what gets checked is exactly what gets
			// fetched. `validate` used to lowercase its own local copy only
			// for its internal checks, leaving the original mixed-case
			// string assigned to the URL; fixed so there is one normalized
			// value, not two that can drift.
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

		/// A strict DNS-hostname allowlist, not a blocklist of dangerous
		/// characters — did:web is spec-defined to be hostname-only
		/// (https://atproto.com/specs/did), so anything this rejects was never
		/// a legitimate identity. This is what closes GER-1912 without
		/// depending on AtprotoTypes' general-purpose `Service.validate`
		/// (unreleased as of this writing), which screens arbitrary URLs and
		/// therefore has to parse IP literals across multiple representations
		/// — a narrower grammar makes that unnecessary here: every IPv4
		/// spelling (dotted, octal, decimal, hex) and every IPv6 literal is
		/// excluded by construction, not by enumeration, because none of them
		/// ends in two alphabetic labels.
		/// `host` must already be lowercased — `documentURL(for:)` is the
		/// only caller, and it normalizes once, upfront, so the string
		/// validated here is exactly the string that ends up in the URL.
		static func validate(host: String) throws {
			// Ports and IPv6 literals both need a literal colon; this
			// resolver supports neither (see the type's doc comment on why
			// localhost/dev is out of scope entirely rather than
			// policy-gated).
			guard !host.contains(":") else { throw Errors.invalidHost }
			// RFC 1035's overall bound, not just the per-label one below —
			// a host built from valid labels can still be a nonsense
			// identity too long for any real hostname.
			guard host.count <= 253 else { throw Errors.invalidHost }

			let labels = host.split(
				separator: ".",
				omittingEmptySubsequences: false
			)
			guard labels.count >= 2 else { throw Errors.invalidHost }
			guard labels.allSatisfy(isValidLabel) else { throw Errors.invalidHost }

			// No public TLD is all-digits — ICANN reserves that shape
			// precisely so a TLD can never collide with an IPv4 address,
			// which is exactly the ambiguity every dotted/octal/decimal IPv4
			// spelling exploits (0177.0.0.1, 2130706433, and so on). Checking
			// the pattern catches all of them without parsing any of them as
			// a number.
			let tld = labels[labels.count - 1]
			guard tld.contains(where: { !$0.isNumber }) else {
				throw Errors.invalidHost
			}

			guard !Self.reservedTLDs.contains(tld) else { throw Errors.invalidHost }
		}

		/// RFC 1123 label grammar: 1–63 ASCII alphanumerics, hyphens allowed
		/// only in the interior (never leading or trailing). Written as
		/// explicit character checks rather than a regex literal — this is
		/// the security-critical predicate in this file, and a character-by-
		/// character reading is easier to audit at a glance than a pattern.
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

		/// IANA special-use domain names (RFC 6761 and the IANA special-use
		/// registry) — never a legitimate public identity, and exactly the
		/// set `AtprotoTypesMocks`' handle-mock fixtures already avoid
		/// colliding with (`.test`).
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
