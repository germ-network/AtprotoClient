//
//  MockPDSErrorTests.swift
//  AtprotoClientTests
//
//  What a rejection from the mock looks like to the caller. This is a property of
//  the mock's error *vocabulary*, not of any one endpoint: `parse` matches the
//  `error` name against the endpoint's `badRequestErrors`, so a name that is not
//  in that set collapses every distinct failure into one opaque
//  `.unrecognized(400 )` — which is what a consumer debugging against the mock
//  used to see.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSErrorTests {
	/// The generic 400s said `"Invalid Request"` — with a space, which is not an
	/// atproto error name — so none of them matched `defaultErrors`.
	@Test("a rejected request arrives as a typed error, not .unrecognized")
	func rejectedRequestsCarryARecognizableErrorName() async throws {
		let (_, _, agent) = try await MockPDSFixture.hosted()

		//a repo that is not the authed one: putRecord's generic 400 guard
		let thrown = await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await agent.putRecord(
				Lexicon.App.Bsky.Graph.Block.self,
				input: .init(
					schema: .init(
						repo: .handle(try .init(string: "example.com")),
						rkey: try .init(string: MockPDSFixture.chosenKey),
						record: MockPDSFixture.block()
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

	/// A miss is `RecordNotFound`, which `GetRecord` declares in its
	/// `notFoundCodes` — so unlike the generic 400s it always parsed, and the
	/// optional-result path turns it into `nil` rather than an error.
	@Test("a missing record reads back as nil, not an error")
	func missingRecordIsNil() async throws {
		let (_, did, agent) = try await MockPDSFixture.hosted()

		let fetched = try await agent.callExpectingOptional(
			Lexicon.Com.Atproto.Repo.GetRecord<Lexicon.App.Bsky.Graph.Block>
				.self,
			parameters: .init(
				repo: .did(did),
				rkey: try .init(string: MockPDSFixture.chosenKey),
				cid: nil
			)
		)

		#expect(fetched == nil)
	}
}
