//
//  BskyCDN.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation

extension Atproto {
	/// Builds Bluesky CDN URLs for a blob reference - a record's blob is a
	/// content reference, not a URL.
	public enum BskyCDN {
		public static let defaultHost = URL(string: "https://cdn.bsky.app")!

		public enum ImageKind: String, Sendable {
			case avatar
			case banner
		}

		/// - Parameter host: Must be a bare `http`/`https` origin (no path,
		///   query, fragment, or userinfo) - throws otherwise. `@jpeg` is a
		///   fixed CDN transcode target, not the blob's actual MIME type.
		public static func imageURL(
			_ kind: ImageKind,
			did: Atproto.DID,
			blob: Atproto.Primitive.Blob,
			host: URL = defaultHost
		) throws -> URL {
			guard
				let components = URLComponents(
					url: host, resolvingAgainstBaseURL: false),
				let scheme = components.scheme?.lowercased(),
				scheme == "https" || scheme == "http",
				let componentHost = components.host, !componentHost.isEmpty,
				components.path.isEmpty || components.path == "/",
				components.query == nil,
				components.fragment == nil,
				components.user == nil,
				components.password == nil
			else {
				throw Errors.invalidHost
			}
			var built = components
			// Normalize the scheme's case so "HTTPS://cdn.bsky.app" and
			// "https://cdn.bsky.app/" both produce the same canonical URL as
			// "https://cdn.bsky.app".
			built.scheme = scheme
			// `did.rawValue` is attacker-influenced (a DID's identifier is
			// otherwise unvalidated) and only percent-encoding "/" out of it
			// stops it from smuggling extra path segments (e.g.
			// "did:plc:../../evil") into the CDN request - `URLComponents.path`
			// leaves "/" alone since it's a legal path character, so this is
			// set through `percentEncodedPath` instead, on an already-escaped
			// string.
			built.percentEncodedPath =
				"/img/\(kind.rawValue)/plain/\(try Self.pathSegment(did.rawValue))/\(try Self.pathSegment(blob.ref.link.string))@jpeg"
			guard let url = built.url else {
				throw Errors.invalidHost
			}
			return url
		}

		// Built explicitly from RFC 3986 (unreserved + sub-delims + ":",
		// excluding "/" and "@") rather than derived from
		// `CharacterSet.urlPathAllowed` - Darwin's built-in set and a
		// modified copy of it don't necessarily encode `:` the same way,
		// which would make exact-URL tests diverge on Linux. Excluding "@"
		// keeps the only literal "@" in the path the fixed "@jpeg" suffix.
		private static let pathSegmentAllowed: CharacterSet = {
			var allowed = CharacterSet()
			allowed.insert(
				charactersIn:
					"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
			)
			allowed.insert(charactersIn: "!$&'()*+,;=")
			allowed.insert(charactersIn: ":")
			return allowed
		}()

		private static func pathSegment(_ value: String) throws -> String {
			guard
				let encoded = value.addingPercentEncoding(
					withAllowedCharacters: Self.pathSegmentAllowed)
			else {
				throw Errors.unencodablePathSegment
			}
			return encoded
		}
	}
}

extension Atproto.BskyCDN {
	public enum Errors: Error, Equatable, Sendable {
		/// `host` isn't a bare `http`/`https` origin (no path, query,
		/// fragment, or userinfo).
		case invalidHost
		/// A DID or CID couldn't be percent-encoded into a path segment.
		case unencodablePathSegment
	}
}

extension Atproto.BskyCDN.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .invalidHost:
			"host must be a bare http(s) origin (no path, query, fragment, or userinfo)"
		case .unencodablePathSegment:
			"a DID or CID could not be percent-encoded into a CDN URL path segment"
		}
	}
}
