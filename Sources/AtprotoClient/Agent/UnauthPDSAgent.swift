//
//  AtprotoUnauthenticatedAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/23/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public struct UnauthPDSAgent {
	public let repo: Atproto.DID
	public let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(
		did: Atproto.DID,
		resourceFetcher: HTTPFetcher = URLSession.shared,
		serviceUrl: URL
	) {
		self.repo = did
		self.resourceFetcher = resourceFetcher
		self.serviceUrl = serviceUrl
	}
}

extension UnauthPDSAgent: AtprotoAgent {
	public func response(
		_ request: BundledHTTPRequest
	) async throws -> HTTPDataResponse {
		try await resourceFetcher.data(for: request)
	}
}
