//
//  GetSocialGraph.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/2/26.
//

import AtprotoTypes
import Foundation

extension Atproto.PDSAgent {
	public func getFollowsStream() async throws -> AsyncMapSequence<
		AsyncThrowingStream<
			[Lexicon.Com.Atproto.Repo.ListRecords<Lexicon.App.Bsky.Graph.Follow>
				.Record], any Error
		>, [Lexicon.App.Bsky.Graph.Follow]
	> {
		try await streamRecords(
			Lexicon.App.Bsky.Graph.Follow.self,
			did: did
		).map { $0.map(\.value) }
	}
}

extension Atproto.PDSAgent {
	public func getBlocksStream() async throws -> AsyncMapSequence<
		AsyncThrowingStream<
			[Lexicon.Com.Atproto.Repo.ListRecords<Lexicon.App.Bsky.Graph.Block>
				.Record], any Error
		>, [Lexicon.App.Bsky.Graph.Block]
	> {
		try await streamRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			did: did
		).map { $0.map(\.value) }
	}
}
