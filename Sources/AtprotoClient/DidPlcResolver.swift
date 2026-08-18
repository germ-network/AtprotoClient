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
	/// Sibling to `DidWebResolver`: identifier validated before use, redirects
	/// refused, and the response's `document.id` checked against the request.
	public struct DidPlcResolver: Sendable {
		public static let defaultDirectory = URL(string: "https://plc.directory")!
		static let acceptHeader = "application/did+ld+json,application/json"

		let directory: URL
		let fetcher: any HTTPFetcher

		/// `directory` must be a bare `https` origin — no path, query,
		/// fragment, or userinfo. Anything else (a trailing slash, most
		/// easily) silently breaks URL construction and turns every
		/// resolution into a `nil`, so it's rejected here instead. `fetcher`
		/// defaults to a redirect-refusing session, for the same reason
		/// `DidWebResolver` refuses one — a followed redirect would bypass
		/// identifier validation, which only runs once, before the request.
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
		/// testable without a network call or a mock.
		static func documentURL(for did: Atproto.DID, directory: URL) throws -> URL {
			guard did.method == .plc else { throw Errors.notDidPlc }
			try validate(identifier: did.identifier)

			// `directory` is already validated — `init` is the only caller
			// with an unvalidated one.
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

		/// did:plc's own grammar: exactly 24 lowercase base32 characters
		/// (https://web.plc.directory/spec/v0.1/did-plc). An allowlist, not a
		/// blocklist — every path-traversal or injection spelling is excluded
		/// by construction.
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
