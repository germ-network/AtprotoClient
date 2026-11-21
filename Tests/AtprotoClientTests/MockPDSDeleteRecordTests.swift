//
//  MockPDSDeleteRecordTests.swift
//  AtprotoClientTests
//
//  `com.atproto.repo.deleteRecord` against `MockPDS`: a deleted record stops
//  reading back, and the delete leaves every other record alone.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSDeleteRecordTests {
	@Test("a deleted record no longer reads back")
	func deletedRecordIsGone() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()
		let output = try await agent.createRecord(MockPDSFixture.block())
		let rkey = try MockPDSFixture.rkey(of: output)

		_ = try await agent.deleteRecord(
			type: Lexicon.App.Bsky.Graph.Block.self,
			rkey: rkey
		)

		let readBack = try await agent.getRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			rkey: rkey,
			cid: nil
		)
		#expect(readBack == nil)
	}

	@Test("deleting one record leaves the others")
	func deleteIsTargeted() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()
		let kept = MockPDSFixture.block()
		let keptOutput = try await agent.createRecord(kept)
		let removedOutput = try await agent.createRecord(MockPDSFixture.block())

		_ = try await agent.deleteRecord(
			type: Lexicon.App.Bsky.Graph.Block.self,
			rkey: try MockPDSFixture.rkey(of: removedOutput)
		)

		let remaining = try await MockPDSFixture.blocks(agent)
		#expect(remaining.map(\.subject) == [kept.subject])
		#expect(
			try await agent.getRecord(
				Lexicon.App.Bsky.Graph.Block.self,
				rkey: try MockPDSFixture.rkey(of: keptOutput),
				cid: nil
			)?.subject == kept.subject
		)
	}
}
