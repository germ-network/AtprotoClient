//
//  AtprotoUnauthenticatedAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/23/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public actor AtprotoUnauthenticatedAgent {
	public nonisolated let repo: Atproto.DID
	public nonisolated let resolver: AtprotoResolver
	private var serviceURL: URL?
	private let resourceFetcher: HTTPFetcher

	public init(
		for did: Atproto.DID,
		resourceFetcher: HTTPFetcher = URLSession.shared,
		resolver: AtprotoResolver,
		serviceURL: URL?
	) {
		self.repo = did
		self.resourceFetcher = resourceFetcher
		self.resolver = resolver
		self.serviceURL = serviceURL
	}
}

extension AtprotoUnauthenticatedAgent: AtprotoAgent {
	public nonisolated var allowsAuthedCalls: Bool { false }

	public func response(_ request: AtprotoAgentRequest) async throws
		-> GermConvenience.HTTPDataResponse
	{
		if serviceURL == nil {
			// Resolve the service URL to the user PDS if not otherwise written
			serviceURL = try await resolver.resolve(did: repo).pdsUrl
		}
		var requestURL = try serviceURL.tryUnwrap.appending(path: request.relativePath)
		requestURL = requestURL.appending(queryItems: request.queryItems)
		let request = URLRequest.createRequest(
			url: requestURL,
			httpMethod: request.httpMethod
		)
		return try await resourceFetcher.data(for: request)
	}

	public func authResponse(_ request: AtprotoAgentRequest) async throws
		-> GermConvenience.HTTPDataResponse
	{
		throw AtprotoAgentError.authedCallsNotPermitted
	}
}
