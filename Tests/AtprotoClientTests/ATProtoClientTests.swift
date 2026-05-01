import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct APIOnlineTests {
	let mockPDS: MockPDS

	init() throws {
		self.mockPDS = try .init()
	}

	@Test func testAtprotoMockSession() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let authAgent = try await mockPDS.host(did: did)

		let record = Lexicon.App.Bsky.Actor.Profile.mock()

		// Prep by storing the record
		let _ = try await authAgent.putRecord(record)

		// Make a request via this mock agent and decode the result
		let profile = try await authAgent.getRecord(
			Lexicon.App.Bsky.Actor.Profile.self
		)

		assert(profile?.displayName == record.displayName)
	}
}
