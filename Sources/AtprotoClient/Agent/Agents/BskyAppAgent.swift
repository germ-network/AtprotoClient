//
//  BskyAppAgent.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

extension Atproto.XRPC {
	//an agent (aka an app-view) that services the app.bsky.* application
	//e.g. https://api.blacksky.community or https://public.api.bsky.app
	public protocol BskyAppCallable: Atproto.XRPC.Callable {
	}
}

//An unauthenticated agent for the Bluesky public api
public struct BskyAppViewAgent {
	let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(
		serviceUrl: URL,
		resourceFetcher: HTTPFetcher
	) throws {
		self.serviceUrl = serviceUrl
		self.resourceFetcher = resourceFetcher
	}

	public static func blackskyAppView(resourceFetcher: HTTPFetcher) throws -> Self {
		try .init(
			serviceUrl: try URL(string: "https://api.blacksky.community").tryUnwrap,
			resourceFetcher: resourceFetcher
		)
	}

	public static func blueskyAppView(resourceFetcher: HTTPFetcher) throws -> Self {
		try .init(
			serviceUrl: try URL(string: "https://public.api.bsky.app").tryUnwrap,
			resourceFetcher: resourceFetcher
		)
	}
}

extension BskyAppViewAgent: Atproto.XRPC.BskyAppCallable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)

		return try await resourceFetcher.data(for: request)
	}
}

extension Atproto.XRPC.BskyAppCallable {
	public func bskyProfile(
		actor: LexiconString.AtIdentifier
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		try await call(
			Lexicon.App.Bsky.Actor.GetProfile.self,
			parameters: .init(actor: actor)
		)
	}
}
