//
//  SocialGraph.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/2/26.
//

import AtprotoTypes
import Foundation

extension PDSAgent {
	public func getFollowsStream(
		did: Atproto.DID,
	) async throws -> any AsyncSequence<[Atproto.DID], Error> {
		try await stream(
			recordType: Lexicon.App.Bsky.Graph.Follow.self,
			did: did
		)
		.map { records in
			records.compactMap {
				// TODO: Log if any of these fail?
				$0.subject
			}
		}
	}
}
