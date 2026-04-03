import Foundation
import Testing

@testable import AtprotoClient
@testable import AtprotoTypes

struct APIOnlineTests {
	struct MockProfileRecord: AtprotoRecord {
		public static let nsid: Atproto.NSID = "app.bsky.actor.profile"
		//		private(set) var nsid: Atproto.NSID = Self.nsid
		public let description: String?
		public let displayName: String?

		//		enum CodingKeys: String, CodingKey {
		//			case nsid = "$type"
		//			case description
		//			case displayName
		//		}

		static func mock() -> APIOnlineTests.MockProfileRecord {
			.init(
				description: "Mock description",
				displayName: "Mock name"
			)
		}
	}

	@Test func testAtprotoMockSession() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let rkey = "self"
		let record = MockProfileRecord.mock()

		let mockAgent = AtprotoMockAgent(
			repo: did,
			recordRegistry: ["app.bsky.actor.profile": MockProfileRecord.self]
		)

		// Prep by storing the record manually (we don't have put record yet)
		try await mockAgent.putRecord(
			record: record,
			repo: .did(did),
			rkey: .init(rawValue: rkey)
		)

		// Make a request via this mock agent and decode the result
		let profile = try await mockAgent.call(
			Lexicon.Com.Atproto.Repo.GetRecord<MockProfileRecord>.self,
			parameters: .init(
				repo: .did(did),
				rkey: .init(rawValue: rkey),
				cid: nil
			)
		)
		assert(profile.value.displayName == record.displayName)
	}
}
