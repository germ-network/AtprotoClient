//
//  SocialGraph.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/2/26.
//

import AtprotoTypes
import Foundation

extension AtprotoClientInterface {
	public func getFollowsStream(
		did: Atproto.DID,
	) async throws -> AsyncThrowingStream<[Atproto.DID], Error> {
		//rely on url caching for this value
		let pdsUrl = try await plcDirectoryQuery(did)
			.pdsUrl

		let (stream, continuation) = AsyncThrowingStream<[Atproto.DID], Error>
			.makeStream(bufferingPolicy: .unbounded)

		Task {
			var cursor: String? = nil
			var fetchCount = 0
			do {
				repeat {
					let result:
						(
							records: [Lexicon.App.Bsky.Graph.Follow],
							cursor: String?
						) =
							try await listRecords(
								pdsUrl: pdsUrl,
								parameters: .init(
									repo: .did(did),
									limit: 100,  // max
									cursor: cursor,
									reverse: nil
								)
							)
					let followingDids = result.records.map(\.subject)
					continuation.yield(followingDids)
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
}

extension AtprotoClientInterface {
	//the client must be auth'd
	public func createBlockRecord(
		myDid: Atproto.DID,
		subject: Atproto.DID,
		session: AtprotoSession
	) async throws {
		let blockRecord = Lexicon.App.Bsky.Graph.Block(
			subject: subject,
			createdAt: .now
		)

		try await createRecord(
			did: myDid,
			parameters: .init(
				repo: .did(myDid),
				rkey: nil,
				record: blockRecord
			),
			session: session
		)
	}
}
