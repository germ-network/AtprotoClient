//
//  PublicPDSAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/23/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public struct PublicPDSAgent: PDSAgent {
	public let repo: Atproto.DID
	let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(
		repo: Atproto.DID,
		resourceFetcher: HTTPFetcher = URLSession.shared,
		serviceUrl: URL
	) {
		self.repo = repo
		self.resourceFetcher = resourceFetcher
		self.serviceUrl = serviceUrl
	}
}

extension PublicPDSAgent: XRPCCallable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)
		return try await resourceFetcher.data(for: request)
	}
}
