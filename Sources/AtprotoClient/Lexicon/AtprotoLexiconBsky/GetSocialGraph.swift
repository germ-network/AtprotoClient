//
//  GetSocialGraph.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/2/26.
//

import AtprotoTypes
import Foundation

extension PDSAgent {
	public func getFollowsStream(
		did: Atproto.DID,
	) async throws -> AsyncMapSequence<AsyncThrowingStream<[Lexicon.Com.Atproto.Repo.ListRecords<Lexicon.App.Bsky.Graph.Follow>.Record], any Error>, [Atproto.DID]
	> {
		try await streamRecords(
			type: Lexicon.App.Bsky.Graph.Follow.self,
			did: did
		)
		.map { records in
			records.compactMap {
				// TODO: Log if any of these fail?
				$0.value.subject
			}
		}
	}
}
