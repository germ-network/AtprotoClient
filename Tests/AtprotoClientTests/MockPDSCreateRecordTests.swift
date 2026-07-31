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
//  The uri test is here for the same reason — minting means `uri` is the only
//  channel back, so it has to agree with what a later read reports.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSCreateRecordTests {
	let mockPDS: MockPDS

	init() throws {
		self.mockPDS = try .init()
	}

	/// The record key the caller gets back has to be a real TID: callers recover
	/// it by splitting `uri`, then feed it to `deleteRecord` as an `Atproto.TID`,
	/// which validates. A UUID or any other filler would store fine and fail there.
	private func rkey(of output: Lexicon.Com.Atproto.Repo.PutRecordOutput) throws
		-> Atproto.TID
	{
		try .init(string: .init(output.uri.split(separator: "/").last ?? ""))
	}

	@Test("a created record reads back at the key the PDS minted")
	func createdRecordReadsBack() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)
		let subject = Atproto.DID.mock()

		let output = try await authAgent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: subject, createdAt: .now)
		)

		let readBack = try await authAgent.getRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			rkey: try rkey(of: output),
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
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)
		let first = Atproto.DID.mock()
		let second = Atproto.DID.mock()

		let firstOutput = try await authAgent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: first, createdAt: .now)
		)
		let secondOutput = try await authAgent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: second, createdAt: .now)
		)

		#expect(try rkey(of: firstOutput) != rkey(of: secondOutput))

		let (records, _) = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		)
		#expect(Set(records.map(\.subject)) == [first, second])
	}

	/// The uri create hands back has to be the uri the same record reports when
	/// read: they are built from different code paths, and they diverged — reads
	/// carried a hardcoded authority and a `NSID(rawValue:)` reflection dump where
	/// the collection belongs, so a caller comparing the two got nonsense.
	@Test("create's uri is the uri the record reports when read")
	func createUriMatchesTheReadUri() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)

		let output = try await authAgent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: .mock(), createdAt: .now)
		)

		let listed = try await authAgent.call(
			Lexicon.Com.Atproto.Repo.ListRecords<Lexicon.App.Bsky.Graph.Block>
				.self,
			parameters: .init(
				repo: .did(did), limit: nil, cursor: nil, reverse: nil)
		)

		#expect(listed.records.map(\.uri.rawValue) == [output.uri])
		#expect(
			output.uri
				== "at://\(did.rawValue)/app.bsky.graph.block/"
				+ "\(try rkey(of: output).rawValue)"
		)
	}

	/// `cid` was the literal string "mock", which is not a CID — no `b` prefix, not
	/// base32 — so anything that fed it back (a swapRecord round trip, say) failed
	/// at the boundary. `PutRecordOutput.cid` is typed `String`, so nothing catches
	/// it at decode; this does. Put returns one too, and it was equally broken.
	@Test("the cid create and put return parses as a CID")
	func returnedCidIsAWellFormedCID() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)

		let created = try await authAgent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: .mock(), createdAt: .now)
		)
		#expect(throws: Never.self) { try Atproto.CID(string: created.cid) }

		let put = try await authAgent.putRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: try .init(string: "3kabcdefghij2"),
					record: .init(subject: .mock(), createdAt: .now)
				)
			)
		)
		#expect(throws: Never.self) { try Atproto.CID(string: put.cid) }
	}

	/// Put chose the key, so its uri is not the only channel back the way create's
	/// is — but it still has to name the record that was written. It returned the
	/// bare placeholder "example.com".
	@Test("put's uri names the record too")
	func putUriNamesTheRecord() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)

		let put = try await authAgent.putRecord(
			Lexicon.App.Bsky.Graph.Block.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: try .init(string: "3kabcdefghij2"),
					record: .init(subject: .mock(), createdAt: .now)
				)
			)
		)

		#expect(put.uri == "at://\(did.rawValue)/app.bsky.graph.block/3kabcdefghij2")
	}

	/// Create mints the key, so a caller that supplies one is refused rather than
	/// quietly given a different key. The alternative — honoring it — would need
	/// the already-exists failure modeled too, and without that it is just
	/// `putRecord` under another name.
	@Test("creating at a caller-chosen key is refused")
	func createWithAnExplicitKeyIsRefused() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)

		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await authAgent.createRecord(
				Lexicon.App.Bsky.Graph.Block(subject: .mock(), createdAt: .now),
				rkey: try .init(string: "3kabcdefghij2")
			)
		}

		guard case .xrpcError(let status, let error) = thrown else {
			Issue.record("expected an xrpc error, got \(String(describing: thrown))")
			return
		}
		#expect(status == .badRequest)
		#expect(error.error == "InvalidRequest")

		let (records, _) = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		)
		#expect(records.isEmpty, "and nothing was written")
	}

	/// The mock's generic 400s said `"Invalid Request"` — with a space, which is not
	/// an atproto error name, so `parse` matched nothing and every one of them
	/// reached the caller as an opaque `.unrecognized(400 )`. They are `InvalidRequest`
	/// now, which is in `defaultErrors`, so a consumer can actually match on them.
	@Test("a rejected request arrives as a typed error, not .unrecognized")
	func rejectedRequestsCarryARecognizableErrorName() async throws {
		let did = Atproto.DID.mock()
		let authAgent = try await mockPDS.host(did: did)

		//repo that is not the authed one: the "Invalid Request" guard in putRecord
		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await authAgent.putRecord(
				Lexicon.App.Bsky.Graph.Block.self,
				input: .init(
					schema: .init(
						repo: .handle(try .init(string: "example.com")),
						rkey: try .init(string: "3kabcdefghij2"),
						record: .init(subject: .mock(), createdAt: .now)
					)
				)
			)
		}

		guard case .xrpcError(let status, let error) = thrown else {
			Issue.record("expected a typed error, got \(String(describing: thrown))")
			return
		}
		#expect(status == .badRequest)
		#expect(error.error == "InvalidRequest")
	}

	/// Unauthenticated callers get 401 rather than a write, same as put. Asserted
	/// on the status, not merely that something threw: an unserved endpoint 400s,
	/// which throws too — so a looser assertion passes with the handler deleted.
	@Test("creating without a session is rejected")
	func createWithoutAuthIsRejected() async throws {
		let did = Atproto.DID.mock()
		let _ = try await mockPDS.host(did: did)
		let publicAgent = try await mockPDS.publicAgent(did: did)

		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await publicAgent.call(
				Lexicon.Com.Atproto.Repo.CreateRecord<
					Lexicon.App.Bsky.Graph.Block
				>.self,
				input: .init(
					schema: .init(
						repo: .did(did),
						rkey: nil,
						record: .init(subject: .mock(), createdAt: .now)
					)
				)
			)
		}

		guard case .xrpcError(let status, _) = thrown else {
			Issue.record("expected a 401, got \(String(describing: thrown))")
			return
		}
		#expect(status == .unauthorized)

		let (records, _) = try await mockPDS.authAgent(did: did)
			.listRecords(
				Lexicon.App.Bsky.Graph.Block.self,
				limit: nil,
				cursor: nil,
				reverse: nil
			)
		#expect(records.isEmpty)
	}
}
