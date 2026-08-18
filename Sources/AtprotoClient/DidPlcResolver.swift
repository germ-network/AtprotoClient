//
//  DidPlcResolver.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

extension Atproto {
	/// Resolves a did:plc identifier by fetching `https://plc.directory/<did>`.
	///
	/// Sibling to `DidWebResolver`, same shape and same reasoning — a did:plc
	/// identifier is likewise attacker-influenced input turned into a fetch
	/// URL, so it's validated (`validate(identifier:)`) before it ever reaches
	/// one, the default transport refuses redirects, and the response is
	/// checked (`document.id == did.rawValue`) rather than trusted.
	public struct DidPlcResolver: Sendable {
		public static let defaultDirectory = URL(string: "https://plc.directory")!
		static let acceptHeader = "application/did+ld+json,application/json"

		let directory: URL
		let fetcher: any HTTPFetcher

		/// `directory` defaults to the canonical PLC directory but is
		/// overridable for a mirror; it must be a bare `https` origin — no
		/// path, query, fragment, or userinfo. `documentURL(for:directory:)`
		/// appends the DID directly onto `directory`'s path, so anything
		/// already there (most easily a trailing slash) silently doubles a
		/// separator and 404s every request — a `directory` shaped that way
		/// fails closed here rather than failing open as "every DID is
		/// unregistered" later. `fetcher` defaults to a redirect-refusing
		/// session — do not override with a redirect-following fetcher in
		/// production, for the same reason `DidWebResolver` refuses one:
		/// identifier validation runs once, before the request, and a
		/// followed redirect bypasses it.
		public init(
			directory: URL = Self.defaultDirectory,
			fetcher: any HTTPFetcher = URLSession.manualRedirect()
		) throws {
			guard
				let components = URLComponents(
					url: directory, resolvingAgainstBaseURL: false),
				components.scheme == "https",
				components.host != nil,
				components.path.isEmpty,
				components.query == nil,
				components.fragment == nil,
				components.user == nil
			else {
				throw Errors.invalidDirectory
			}
			self.directory = directory
			self.fetcher = fetcher
		}

		/// `nil` for a well-formed request the endpoint declined (including a
		/// tombstoned, `410`-status DID); throws for anything that means this
		/// resolver or the document can't be trusted.
		public func resolve(did: Atproto.DID) async throws -> Atproto.DIDDocument? {
			let url = try Self.documentURL(for: did, directory: directory)

			let request = try BundledHTTPRequest(
				url: url,
				headerFields: [.accept: Self.acceptHeader]
			)
			let response = try await fetcher.data(for: request)

			if response.response.status.kind == .redirection {
				throw Errors.redirectRefused
			}
			guard response.response.status.kind == .successful else {
				return nil
			}

			let document: Atproto.DIDDocument = try response.data.decode()
			guard document.id == did.rawValue else {
				throw Errors.documentIdMismatch(
					requested: did.rawValue,
					returned: document.id
				)
			}
			return document
		}

		/// Pure and synchronous — every security-relevant decision here is
		/// testable without a network call or a mock. `directory` is trusted
		/// to already be a validated bare origin — `init` is the only caller
		/// with an unvalidated one, and it never reaches this far.
		static func documentURL(for did: Atproto.DID, directory: URL) throws -> URL {
			guard did.method == .plc else { throw Errors.notDidPlc }
			try validate(identifier: did.identifier)

			guard
				var components = URLComponents(
					url: directory, resolvingAgainstBaseURL: false)
			else {
				throw Errors.invalidDirectory
			}
			components.path = "/" + did.rawValue
			guard let url = components.url else {
				throw Errors.invalidDirectory
			}
			return url
		}

		/// did:plc's own grammar (https://web.plc.directory/spec/v0.1/did-plc):
		/// exactly 24 characters, lowercase `a`–`z` and `2`–`7` only — base32
		/// minus the digits that read as letters. An allowlist, not a
		/// blocklist: `/`, `.`, `%`, `?`, `#`, `:`, uppercase, and every path-
		/// traversal spelling are excluded by construction.
		static func validate(identifier: String) throws {
			guard identifier.count == 24 else { throw Errors.invalidIdentifier }
			guard identifier.allSatisfy(isValidIdentifierCharacter) else {
				throw Errors.invalidIdentifier
			}
		}

		private static func isValidIdentifierCharacter(_ char: Character) -> Bool {
			guard char.isASCII, let ascii = char.asciiValue else { return false }
			switch ascii {
			case UInt8(ascii: "a")...UInt8(ascii: "z"): return true
			case UInt8(ascii: "2")...UInt8(ascii: "7"): return true
			default: return false
			}
		}
	}
}

extension Atproto.DidPlcResolver {
	public enum Errors: Error, Equatable, Sendable {
		case notDidPlc
		case invalidIdentifier
		case invalidDirectory
		case redirectRefused
		case documentIdMismatch(requested: String, returned: String)
	}
}

extension Atproto.DidPlcResolver.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .notDidPlc: "DID is not a did:plc identifier"
		case .invalidIdentifier: "did:plc identifier is not 24 base32 characters"
		case .invalidDirectory: "PLC directory URL must be a bare https origin"
		case .redirectRefused: "the PLC directory attempted a redirect, which is refused"
		case .documentIdMismatch(let requested, let returned):
			"resolved document id \"\(returned)\" does not match requested DID \"\(requested)\""
		}
	}
}
