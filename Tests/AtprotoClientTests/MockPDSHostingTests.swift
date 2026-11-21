//
//  MockPDSHostingTests.swift
//  AtprotoClientTests
//
//  Which repos a `MockPDS` will act for, and what it says to requests it will
//  not serve: a repo it does not host, and a write with no authenticated DID.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import GermConvenienceHTTP
import Testing

struct MockPDSHostingTests {
	@Test("a DID can only be hosted once")
	func hostingTwiceThrows() async throws {
		let (pds, did, _) = try await MockPDSFixture.hosted()

		await #expect(throws: (any Error).self) {
			try await pds.host(did: did)
		}
	}

	@Test("agents are only vended for hosted DIDs")
	func agentsRequireAHostedDID() async throws {
		let (pds, did, _) = try await MockPDSFixture.hosted()
		let stranger = Atproto.DID.mock()

		#expect(try await pds.authAgent(did: did).did == did)
		#expect(try await pds.publicAgent(did: did).did == did)
		await #expect(throws: (any Error).self) {
			try await pds.authAgent(did: stranger)
		}
		await #expect(throws: (any Error).self) {
			try await pds.publicAgent(did: stranger)
		}
	}

	@Test("getRecord for a repo the PDS does not host is InvalidRequest")
	func getRecordForUnhostedRepo() async throws {
		let (pds, _, _) = try await MockPDSFixture.hosted()

		let response = try await pds.response(
			.init(
				relativePath: "/xrpc/com.atproto.repo.getRecord",
				queryItems: [
					.init(name: "repo", value: Atproto.DID.mock().rawValue),
					.init(name: "collection", value: "app.bsky.graph.block"),
					.init(name: "rkey", value: MockPDSFixture.chosenKey),
				],
				headers: [:],
				method: .get
			),
			authedDid: nil
		)

		#expect(response.response.status == .badRequest)
	}

	@Test(
		"a write with no authenticated DID is Unauthorized",
		arguments: [
			"com.atproto.repo.createRecord",
			"com.atproto.repo.putRecord",
			"com.atproto.repo.deleteRecord",
		]
	)
	func unauthenticatedWriteIsRejected(nsid: String) async throws {
		let (pds, _, _) = try await MockPDSFixture.hosted()

		let response = try await pds.response(
			.init(
				relativePath: "/xrpc/\(nsid)",
				queryItems: [],
				headers: [.contentType: "application/json"],
				method: .post,
				body: Data("{}".utf8)
			),
			authedDid: nil
		)

		#expect(response.response.status == .unauthorized)
	}
}
