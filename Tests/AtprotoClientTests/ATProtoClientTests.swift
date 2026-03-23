import Foundation
import Testing

@testable import AtprotoClient
@testable import AtprotoTypes

struct APIOnlineTests {
	let resolver = AtprotoLegacyResolver(resourceFetcher: URLSession.shared)

	struct MockProfileRecord: AtprotoRecord {
		public static let nsid: Atproto.NSID = "app.bsky.actor.profile"
		private(set) var nsid: Atproto.NSID = Self.nsid
		public let description: String?
		public let displayName: String?

		static func mock() -> APIOnlineTests.MockProfileRecord {
			.init(
				description: "Mock description",
				displayName: "Mock name"
			)
		}
	}

	// Check Mark's profile record
	@Test func testExistingRecord() async throws {
		//		let did = try Atproto.DID(string: "did:plc:lbu36k4mysk5g6gcrpw4dbwm")
		//
		//		let client = AtprotoClient(
		//			agent: AtprotoAgentImpl(
		//				for: did,
		//				resolver: resolver
		//			)
		//		)
		//		let result: MockProfileRecord? = try await client.getRecord(
		//			parameters: .init(
		//				repo: .did(did),
		//				rkey: "self",
		//				cid: nil
		//			)
		//		)
		//		#expect(result?.nsid == MockProfileRecord.nsid)
	}

	@Test func testAtprotoMockSession() async throws {
		//		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		//		let rkey = "self"
		//		let record = MockProfileRecord.mock()
		//
		//		let mockAgent = AtprotoMockAgentImpl(for: did)
		//		let client = AtprotoClient(agent: mockAgent)
		//
		//		// Prep by storing the record manually (we don't have put record yet)
		//		try await mockAgent.putRecord(
		//			record: record,
		//			repo: did.stringRepresentation,
		//			rkey: rkey
		//		)
		//
		//		// Make a request via this mock agent and decode the result
		//		let profile = try await client.request(
		//			Lexicon.Com.Atproto.Repo.GetRecord<MockProfileRecord>.self,
		//			parameters: .init(
		//				repo: .did(did),
		//				rkey: rkey,
		//				cid: nil
		//			)
		//		)
		//		assert(profile.value.displayName == record.displayName)
	}
}
