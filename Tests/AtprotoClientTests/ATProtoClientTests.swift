import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import Testing

struct MockPDSTests {
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
	
	@Test func testFollows() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let authAgent = try await mockPDS.host(did: did)

		let mockFollow = Atproto.DID.mock()
		let mockBlock = Atproto.DID.mock()
		
		try await authAgent.pds.follow(did: mockFollow, from: did)
		try await authAgent.pds.block(did: mockBlock, from: did)
		
		let _ = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Follow.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		)
		
		let _ = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		)
	}
	
	@Test func testFollowsCursor() async throws {
		let did: Atproto.DID = try .init(string: "did:plc:mynameisanna")
		let authAgent = try await mockPDS.host(did: did)

		for _ in 0..<10 {
			let mockFollow = Atproto.DID.mock()
			try await authAgent.pds.follow(did: mockFollow, from: did)
		}
		
		let mockBlock = Atproto.DID.mock()
		try await authAgent.pds.block(did: mockBlock, from: did)
		
		let _ = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Follow.self,
			limit: 5,
			cursor: nil,
			reverse: nil
		)
		
		let _ = try await authAgent.listRecords(
			Lexicon.App.Bsky.Graph.Block.self,
			limit: nil,
			cursor: nil,
			reverse: nil
		)
	}
}
