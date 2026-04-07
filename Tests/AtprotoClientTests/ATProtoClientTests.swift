import Foundation
import Testing

@testable import AtprotoClient
@testable import AtprotoTypes

struct APIOnlineTests {
	let mockPDS: MockPDS

	init() throws {
		self.mockPDS = try .init()
	}

	@Test func testAtprotoMockSession() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let authAgent = try await mockPDS.host(did: did)

		let record = Lexicon.App.Bsky.Actor.Profile.mock()
		await mockPDS.register(type: Lexicon.App.Bsky.Actor.Profile.self)

		// Prep by storing the record
		let _ = try await authAgent.putRecord(record)

		// Make a request via this mock agent and decode the result
		let profile = try await authAgent.getRecord(
			type: Lexicon.App.Bsky.Actor.Profile.self
		)

		assert(profile?.displayName == record.displayName)
	}
}
