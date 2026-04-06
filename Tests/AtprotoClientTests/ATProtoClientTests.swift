import Foundation
import Testing

@testable import AtprotoClient
@testable import AtprotoTypes

struct APIOnlineTests {
	

	@Test func testAtprotoMockSession() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let record = Lexicon.App.Bsky.Actor.Profile.mock()

		let mockAgent = AtprotoMockAgent(
			repo: did,
			recordRegistry: ["app.bsky.actor.profile": Lexicon.App.Bsky.Actor.Profile.self]
		)

		// Prep by storing the record
		let _ = try await mockAgent.putRecord(record)
		
		// Make a request via this mock agent and decode the result
		let profile = try await mockAgent.getRecord(
			type: Lexicon.App.Bsky.Actor.Profile.self
		)
		
		assert(profile?.displayName == record.displayName)
	}
}
