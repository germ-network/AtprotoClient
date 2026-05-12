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

public enum BskyGraphs: Sendable {
	case follows
	case blocks
	case knownFollowers

	enum Errors: LocalizedError {
		case notImplemented

		var errorDescription: String? {
			switch self {
			case .notImplemented: "Not implemented"
			}
		}
	}
}

extension Atproto.XRPC.BskyAppCallable {

	public func streamProfileViews(
		for actor: LexiconString.AtIdentifier,
		graphType: BskyGraphs,
	) async throws -> AsyncThrowingStream<
		[Lexicon.App.Bsky.Actor.Defs.ProfileView], Error
	> {
		let (stream, continuation) = AsyncThrowingStream<
			[Lexicon.App.Bsky.Actor.Defs.ProfileView], Error
		>
		.makeStream(bufferingPolicy: .unbounded)

		Task {
			var cursor: String? = nil
			var fetchCount = 0
			do {
				repeat {
					let result:
						(
							profiles: [Lexicon.App.Bsky.Actor.Defs
								.ProfileView],
							cursor: String?
						) =
							try await getProfileBatch(
								for: actor,
								graphType: graphType,
								cursor: cursor
							)
					continuation.yield(result.profiles)
					cursor = result.cursor
					fetchCount += 1
				} while cursor != nil && fetchCount < ATProtoConstants.maxFetches
				continuation.finish()
			} catch {
				continuation.finish(throwing: error)
			}
		}
		return stream
	}

	private func getProfileBatch(
		for actor: LexiconString.AtIdentifier,
		graphType: BskyGraphs,
		cursor: String?
	) async throws -> (
		[Lexicon.App.Bsky.Actor.Defs.ProfileView], String?
	) {
		switch graphType {
		case .blocks:
			throw BskyGraphs.Errors.notImplemented
		case .follows:
			try await call(
				Lexicon.App.Bsky.Graph.GetFollows.self,
				parameters: .init(
					actor: actor,
					limit: 100,
					cursor: cursor
				)
			).profileBatch
		case .knownFollowers:
			throw BskyGraphs.Errors.notImplemented
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetFollows.Output {
	var profileBatch: ([Lexicon.App.Bsky.Actor.Defs.ProfileView], String?) {
		(follows, cursor)
	}
}
