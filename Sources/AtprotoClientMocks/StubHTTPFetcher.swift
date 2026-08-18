//
//  StubHTTPFetcher.swift
//  AtprotoClientMocks
//

import Foundation
import GermConvenience

/// A canned-response `HTTPFetcher`, for anything built on the seam.
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
