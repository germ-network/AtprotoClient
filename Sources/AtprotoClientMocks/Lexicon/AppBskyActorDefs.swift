//
//  AppBskyActorDefs.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/13/26.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import Mockable

extension Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed: Mockable {
	public static func mock() -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		.init(
			did: .mock(),
			handle: "germnetwork.com",
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
