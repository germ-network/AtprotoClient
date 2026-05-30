//
//  OnlineTests.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 5/20/26.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import Testing

struct OnlineTests {
	let appView: BskyAppViewAgent

	init() throws {
		appView = try .blueskyAppView(resourceFetcher: URLSession.shared)
	}

	@Test func testGetRelationship() async throws {
		let result = try await appView.call(
			Lexicon.App.Bsky.Graph.GetRelationships.self,
			parameters: .init(
				actor: .did(.init(string: "did:plc:4yvwfwxfz5sney4twepuzdu7")),
				others: [
					.did(.init(string: "did:plc:kta7dqcqoamo5ixlajxbtjps")),
					.handle(.init(string: "example.com")),
				]
			)
		)
		print(result)
	}

}
