//
//  GetAuthedSocialGraph.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/2/26.
//

import AtprotoTypes
import Foundation

public enum BskyAppViewAuthedSocialGraphs: Sendable {
	case blocks
	case knownFollowers
}

extension AuthPDSAgent {
	public func streamSocialGraphs(
		for actor: LexiconString.AtIdentifier,
		socialGraphType: BskyAppViewAuthedSocialGraphs,
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
								socialGraphType: socialGraphType,
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
		socialGraphType: BskyAppViewAuthedSocialGraphs,
		cursor: String?
	) async throws -> (
		[Lexicon.App.Bsky.Actor.Defs.ProfileView], String?
	) {
		switch socialGraphType {
		case .blocks:
			try await call(
				Lexicon.App.Bsky.Graph.GetBlocks.self,
				parameters: .init(
					limit: 100,
					cursor: cursor
				)
			).profileBatch
		case .knownFollowers:
			try await call(
				Lexicon.App.Bsky.Graph.GetKnownFollowers.self,
				parameters: .init(
					actor: actor,
					limit: 100,
					cursor: cursor
				)
			).profileBatch
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetKnownFollowers.Output {
	var profileBatch: ([Lexicon.App.Bsky.Actor.Defs.ProfileView], String?) {
		(followers, cursor)
	}
}

extension Lexicon.App.Bsky.Graph.GetBlocks.Output {
	var profileBatch: ([Lexicon.App.Bsky.Actor.Defs.ProfileView], String?) {
		(blocks, cursor)
	}
}
