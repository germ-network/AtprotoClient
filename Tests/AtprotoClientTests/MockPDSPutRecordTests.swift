//
//  MockPDSPutRecordTests.swift
//  AtprotoClientTests
//
//  `com.atproto.repo.putRecord`'s response shape. The endpoint itself predates
//  these tests and is exercised throughout the mock suites; what was never
//  asserted is what it hands *back*, and both fields were wrong: a placeholder
//  uri that named no record, and a cid that was not a CID.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSPutRecordTests {
	private func put(
		_ agent: MockPDS.AuthAgent,
		did: Atproto.DID
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecordOutput {
		try await agent.putRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: try .init(string: MockPDSFixture.chosenKey),
					record: MockPDSFixture.block()
				)
			)
		)
	}

	/// Put chose the key, so its uri is not the only channel back the way create's
	/// is — but it still has to name the record that was written. It returned the
	/// bare placeholder "example.com".
	@Test("put's uri names the record")
	func putUriNamesTheRecord() async throws {
		let (_, did, agent) = try await MockPDSFixture.hosted()

		let output = try await put(agent, did: did)

		#expect(
			output.uri
				== "at://\(did.rawValue)/app.bsky.graph.block/"
				+ MockPDSFixture.chosenKey
		)
	}

	/// `cid` was the literal string "mock", which is not a CID — no `b` prefix, not
	/// base32 — so anything that fed it back (a swapRecord round trip, say) failed
	/// at the boundary. `PutRecordOutput.cid` is typed `String`, so nothing catches
	/// it at decode; this does.
	@Test("the cid put returns parses as a CID")
	func putReturnsAWellFormedCID() async throws {
		let (_, did, agent) = try await MockPDSFixture.hosted()

		let output = try await put(agent, did: did)

		#expect(throws: Never.self) { try Atproto.CID(string: output.cid) }
	}
}
