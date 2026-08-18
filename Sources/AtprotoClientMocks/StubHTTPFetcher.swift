//
//  StubHTTPFetcher.swift
//  AtprotoClientMocks
//

import Foundation
import GermConvenience

/// A canned-response `HTTPFetcher` — not did:web-specific, usable for
/// anything built on the `HTTPFetcher` seam. Deliberately the *only* place a
/// caller can inject a fetcher into `Atproto.DidWebResolver`: production
/// callers get the safe, redirect-refusing default.
public struct StubHTTPFetcher: HTTPFetcher, Sendable {
	private let handler: @Sendable (BundledHTTPRequest) throws -> HTTPDataResponse

	public init(
		_ handler: @escaping @Sendable (BundledHTTPRequest) throws -> HTTPDataResponse
	) {
		self.handler = handler
	}

	public init(_ response: HTTPDataResponse) {
		self.handler = { _ in response }
	}

	public func data(for request: BundledHTTPRequest) async throws -> HTTPDataResponse {
		try handler(request)
	}
}
