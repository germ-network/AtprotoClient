//
//  WellKnownHandleResolver.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP
import HTTPTypes

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

extension Atproto {
	/// Resolves an atproto handle by fetching
	/// `https://<handle>/.well-known/atproto-did`, as specified at
	/// https://atproto.com/specs/handle#https-well-known-method.
	///
	/// Sibling to `DidWebResolver`/`DidPlcResolver`: redirects are refused,
	/// and the parsed value is only ever handed back through
	/// `Atproto.DID.init(string:)`, which validates it.
	public struct WellKnownHandleResolver: Sendable {
		static let wellKnownPath = "/.well-known/atproto-did"
		static let acceptHeader = "text/plain;charset=UTF-8"
		/// A generous bound on a body that should be one short line - a DID is
		/// at most 2KB (https://atproto.com/specs/did) - so nothing this size
		/// is ever a legitimate answer. Checked before the body is parsed, so
		/// an oversized response is rejected rather than processed.
		static let maxBodySize = 8192

		let fetcher: any HTTPFetcher

		/// Defaults to a redirect-refusing session, for the same reason
		/// `DidWebResolver` refuses one - the handle is already validated, but
		/// a followed redirect would fetch a second, unvalidated host.
		public init(fetcher: any HTTPFetcher = URLSession.manualRedirect()) {
			self.fetcher = fetcher
		}

		/// `nil` for a well-formed request the endpoint declined (a non-2xx
		/// status, or a 2xx with an empty body); throws for anything that
		/// means this resolver or the response can't be trusted.
		public func resolve(handle: Atproto.Handle) async throws -> Atproto.DID? {
			let url = try Self.wellKnownURL(for: handle)

			let request = try BundledHTTPRequest(
				url: url,
				headerFields: [.accept: Self.acceptHeader]
			)
			let response = try await fetcher.data(for: request)

			if response.response.status.kind == .redirection {
				// A refused redirect surfaces as its own response rather than
				// being followed - distinct from an ordinary 4xx/5xx.
				throw Errors.redirectRefused
			}
			guard response.response.status.kind == .successful else {
				return nil
			}
			guard response.data.count <= Self.maxBodySize else {
				throw Errors.responseTooLarge
			}

			let body = String(decoding: response.data, as: UTF8.self)
			guard
				let firstLine = body.split(
					separator: "\n", maxSplits: 1,
					omittingEmptySubsequences: false
				).first
			else {
				return nil
			}
			let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else {
				return nil
			}

			return try Atproto.DID(string: trimmed)
		}

		/// Pure and synchronous - every security-relevant decision here is
		/// testable without a network call or a mock.
		static func wellKnownURL(for handle: Atproto.Handle) throws -> URL {
			var components = URLComponents()
			components.scheme = "https"
			components.host = handle.rawValue
			components.path = Self.wellKnownPath

			guard let url = components.url, let host = url.host, !host.isEmpty else {
				// Not reachable through a `Handle` that already passed its own
				// grammar check - kept as defense in depth rather than a
				// force-unwrap, since the handle drives a network fetch.
				throw Errors.invalidHandle
			}
			return url
		}
	}
}

extension Atproto.WellKnownHandleResolver {
	public enum Errors: Error, Equatable, Sendable {
		case invalidHandle
		case redirectRefused
		case responseTooLarge
	}
}

extension Atproto.WellKnownHandleResolver.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .invalidHandle: "handle could not be resolved to a well-known URL"
		case .redirectRefused:
			"the well-known endpoint attempted a redirect, which is refused"
		case .responseTooLarge: "the well-known response body exceeded the size bound"
		}
	}
}
