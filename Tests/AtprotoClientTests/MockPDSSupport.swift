//
//  MockPDSSupport.swift
//  AtprotoClientTests
//
//  Shared setup for the MockPDS suites: a hosted repo, and the record-key
//  recovery every write assertion needs.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation

enum MockPDSFixture {
	//a valid TID: 13 characters from the base32-sortable alphabet, leading
	//character from the narrower prefix set. Anything else fails `Atproto.TID`
	//validation before it reaches the repo.
	static let chosenKey = "3kabcdefghij2"

	/// A PDS hosting one repo, and an agent authed as it.
	static func hosted() async throws -> (
		pds: MockPDS, did: Atproto.DID, agent: MockPDS.AuthAgent
	) {
		let pds = try MockPDS()
		let did = Atproto.DID.mock()
		return (pds, did, try await pds.host(did: did))
	}

	/// The record key out of a write's `uri`. It has to survive `Atproto.TID`
	/// validation, because that is exactly what callers do with it: recover it by
	/// splitting the uri, then hand it to `deleteRecord` as a typed key. A UUID or
	/// any other filler would store fine here and fail there.
	static func rkey(
		of output: Lexicon.Com.Atproto.Repo.PutRecordOutput
	) throws -> Atproto.TID {
		try .init(string: .init(output.uri.split(separator: "/").last ?? ""))
	}

	static func blocks(
		_ agent: MockPDS.AuthAgent
	) async throws -> [Lexicon.App.Bsky.Graph.Block] {
		try await agent.listRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		).0
	}

	static func block() -> Lexicon.App.Bsky.Graph.Block {
		.init(subject: .mock(), createdAt: .now)
	}
}
