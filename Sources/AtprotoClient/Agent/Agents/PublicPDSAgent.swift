//
//  PublicPDSAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/23/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public struct PublicPDSAgent: Atproto.PDSAgent {
	public let did: Atproto.DID
	let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(
		did: Atproto.DID,
		resourceFetcher: HTTPFetcher,
		serviceUrl: URL
	) {
		self.did = did
		self.resourceFetcher = resourceFetcher
		self.serviceUrl = serviceUrl
	}
}

extension PublicPDSAgent: Atproto.XRPC.Callable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)
		return try await resourceFetcher.data(for: request)
	}
}
