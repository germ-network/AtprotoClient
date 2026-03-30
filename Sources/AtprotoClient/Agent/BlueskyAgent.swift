//
//  BlueskyAgent.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import Foundation
import GermConvenience

//An unauthenticated agent for the Bluesky public api
public struct BlueskyPublicAgent {
	public let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(resourceFetcher: HTTPFetcher = URLSession.shared) throws {
		self.serviceUrl = try URL(string: "https://public.api.bsky.app").tryUnwrap
		self.resourceFetcher = resourceFetcher
	}
}

extension BlueskyPublicAgent: AtprotoAgent {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)
		
		return try await resourceFetcher.data(for: request)
	}
}
