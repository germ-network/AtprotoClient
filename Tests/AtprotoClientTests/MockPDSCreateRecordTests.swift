//
//  MockPDSCreateRecordTests.swift
//  AtprotoClientTests
//
//  `com.atproto.repo.createRecord` against `MockPDS`. Before it was served, any
//  production path that creates a record — blocking someone, say — could not be
//  tested against the mock at all: it 400'd on the way in.
//
//  What distinguishes create from put is that the PDS, not the caller, picks the
//  record key, so most of what follows is about the key: it comes back as a usable
//  TID, a second create does not land on top of the first, and a caller who tries
//  to choose one is refused rather than quietly handed a different key.
//
//  Minting is also why `uri` matters here — it is the only channel back — so it
//  has to agree with what a later read reports. Put's own response shape lives in
//  `MockPDSPutRecordTests`.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSCreateRecordTests {
	@Test("a created record reads back at the key the PDS minted")
	func createdRecordReadsBack() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()
		let subject = Atproto.DID.mock()

		let output = try await agent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: subject, createdAt: .now)
		)

		let readBack = try await agent.getRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			rkey: try MockPDSFixture.rkey(of: output),
			cid: nil
		)

		#expect(readBack?.subject == subject)
	}

	/// The property that separates create from put: put twice at one key leaves
	/// one record, create twice leaves two. A handler that reused a fixed key —
	/// or read a key out of an input that carries none — would pass the test
	/// above and fail this one.
	@Test("two creates write two distinct records")
	func twoCreatesWriteTwoRecords() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()
		let first = Atproto.DID.mock()
		let second = Atproto.DID.mock()

		let firstOutput = try await agent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: first, createdAt: .now)
		)
		let secondOutput = try await agent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: second, createdAt: .now)
		)

		#expect(
			try MockPDSFixture.rkey(of: firstOutput)
				!= MockPDSFixture.rkey(of: secondOutput)
		)
		#expect(
			Set(try await MockPDSFixture.blocks(agent).map(\.subject))
				== [first, second]
		)
	}

	/// The uri create hands back has to be the uri the same record reports when
	/// read: they are built from different code paths, and they diverged — reads
	/// carried a hardcoded authority and a `NSID(rawValue:)` reflection dump where
	/// the collection belongs, so a caller comparing the two got nonsense. Both
	/// read paths are checked, since each embeds a uri of its own.
	@Test("create's uri is the uri the record reports when read")
	func createUriMatchesTheReadUri() async throws {
		let (_, did, agent) = try await MockPDSFixture.hosted()

		let output = try await agent.createRecord(MockPDSFixture.block())
		let rkey = try MockPDSFixture.rkey(of: output)

		#expect(
			output.uri == "at://\(did.rawValue)/app.bsky.graph.block/\(rkey.rawValue)"
		)

		let listed = try await agent.call(
			Lexicon.Com.Atproto.Repo.ListRecords<Lexicon.App.Bsky.Graph.Block>
				.self,
			parameters: .init(
				repo: .did(did), limit: nil, cursor: nil, reverse: nil)
		)
		#expect(listed.records.map(\.uri.rawValue) == [output.uri])

		//getRecord embeds a uri too, on a path listRecords does not share
		let fetched = try await agent.callExpectingOptional(
			Lexicon.Com.Atproto.Repo.GetRecord<Lexicon.App.Bsky.Graph.Block>
				.self,
			parameters: .init(repo: .did(did), rkey: rkey, cid: nil)
		)
		#expect(fetched?.uri.rawValue == output.uri)
	}

	@Test("the cid create returns parses as a CID")
	func createReturnsAWellFormedCID() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()

		let output = try await agent.createRecord(MockPDSFixture.block())

		#expect(throws: Never.self) { try Atproto.CID(string: output.cid) }
	}

	/// Create mints the key, so a caller that supplies one is refused rather than
	/// quietly given a different key. The alternative — honoring it — would need
	/// the already-exists failure modeled too, and without that it is just
	/// `putRecord` under another name.
	@Test("creating at a caller-chosen key is refused")
	func createWithAnExplicitKeyIsRefused() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()

		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await agent.createRecord(
				MockPDSFixture.block(),
				rkey: try .init(string: MockPDSFixture.chosenKey)
			)
		}

		guard case .xrpcError(let status, let error) = thrown else {
			Issue.record("expected an xrpc error, got \(String(describing: thrown))")
			return
		}
		#expect(status == .badRequest)
		#expect(error.error == "InvalidRequest")
		#expect(try await MockPDSFixture.blocks(agent).isEmpty, "and nothing was written")
	}

	/// Unauthenticated callers get 401 rather than a write, same as put. Asserted
	/// on the status, not merely that something threw: an unserved endpoint 400s,
	/// which throws too — so a looser assertion passes with the handler deleted.
	@Test("creating without a session is rejected")
	func createWithoutAuthIsRejected() async throws {
		let (pds, did, agent) = try await MockPDSFixture.hosted()
		let publicAgent = try await pds.publicAgent(did: did)

		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await publicAgent.call(
				Lexicon.Com.Atproto.Repo.CreateRecord<
					Lexicon.App.Bsky.Graph.Block
				>.self,
				input: .init(
					schema: .init(
						repo: .did(did),
						rkey: nil,
						record: MockPDSFixture.block()
					)
				)
			)
		}

		guard case .xrpcError(let status, _) = thrown else {
			Issue.record("expected a 401, got \(String(describing: thrown))")
			return
		}
		#expect(status == .unauthorized)
		#expect(try await MockPDSFixture.blocks(agent).isEmpty)
	}
}
