//
//  MockRepoResilienceTests.swift
//  AtprotoClientTests
//
//  A single un-decodable record in a graph collection (a foreign/malformed
//  record, or one written by a newer schema) must not break the whole read or
//  the unfollow. Both `getGraph` and `unfollow` decode best-effort: they skip a
//  record they can't parse rather than throwing on it. Before that fix, either
//  would abort on the first bad record.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import Testing

@testable import AtprotoClientMocks

struct MockRepoResilienceTests {
	@Test func graphReadAndUnfollowSkipUndecodableFollowRecords() async throws {
		let repo = try MockRepo()
		let collection = Lexicon.App.Bsky.Graph.Follow.Collection.nsid

		let keep = Atproto.DID.mock()
		try await repo.follow(did: keep)

		//a record that is NOT a valid Follow, sitting in the Follow collection
		try await repo.putRecord(
			collection: collection,
			rkey: "not-a-follow",
			encodedRecord: Data(#"{"unexpected":"shape"}"#.utf8)
		)

		//getGraph must not throw on the bad record, and returns the one it can read
		let (follows, _) = await repo.getGraph()
		#expect(follows.count == 1)
		#expect(follows.first?.subject == keep)

		//unfollow must not throw either, and removes the real follow while the
		//un-decodable record (which it can't match) is simply skipped
		await repo.unfollow(did: keep)
		let (afterFollows, _) = await repo.getGraph()
		#expect(afterFollows.isEmpty)
	}
}
