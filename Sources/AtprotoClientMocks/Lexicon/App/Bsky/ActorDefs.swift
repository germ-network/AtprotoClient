//
//  AppBskyActorDefs.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/13/26.
//

import AtprotoClient
import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import Mockable

extension Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed: Mockable {
	public static func mock() throws -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		.init(
			did: .mock(),
			handle: try .init(string: "example.com"),
			displayName: "profile for Bluesky Actor",
			description: "mock description",
			pronouns: "it/them",
			website: nil,
			avatar: nil,
			banner: nil,
			followersCount: 2,
			followsCount: 5,
			postsCount: 10,
			indexedAt: .init(date: .now),
			createdAt: .init(date: .distantPast),
			viewer: .init(
				muted: false,
				blockedBy: true,
				blocking: .mock(),
				following: .mock(),
				followedBy: .mock(),
			)
		)
	}
}

extension Lexicon.App.Bsky.Actor.Profile: Mockable {
	public static func mock() -> Lexicon.App.Bsky.Actor.Profile {
		.init(
			avatar: nil,
			banner: nil,
			createdAt: .now,
			description: "Share what you want to, when you need to.",
			displayName: "Germ Network",
			pronouns: "they/them",
			website: nil
		)
	}
}
