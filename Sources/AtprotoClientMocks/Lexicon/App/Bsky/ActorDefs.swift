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
			handle: try .init(string: "germnetwork.com"),
			displayName: "Germ Network",
			pronouns: "it/them",
			avatar: URL(string: "https://example.com/avatar.jpg"),
			viewer: .init(
				muted: false,
				blockedBy: true,
				blocking: "placeholder",
				following: "placeholder",
				followedBy: "placeholder"
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
