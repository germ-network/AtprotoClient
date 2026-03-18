import Foundation
import Testing

@testable import AtprotoClient
@testable import AtprotoTypes

struct APIOnlineTests {
	@Test func testProfileFetch() async throws {
		let did = try Atproto.DID(string: "did:plc:lbu36k4mysk5g6gcrpw4dbwm")

		let result = try await AtprotoClient(resourceFetcher: URLSession.shared)
			.getProfile(did: did)

		#expect(result?.nsid == "app.bsky.actor.profile")
	}
}
