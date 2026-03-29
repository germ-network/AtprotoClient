//
//  BskyGetProfile.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

///https://docs.bsky.app/docs/api/app-bsky-actor-get-profile
///https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.actor.getProfile/docs
extension Lexicon.App.Bsky.Actor {
	public enum GetProfile: XRPCRequest {
		public typealias Output = Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed

		public static var nsid: String { "app.bsky.actor.getProfile" }
		public static var acceptValue: HTTPContentType { .json }

		public struct Parameters: QueryParametrizable {
			public let actor: AtIdentifier

			public init(actor: AtIdentifier) {
				self.actor = actor
			}

			public func asQueryItems() -> [URLQueryItem] {
				[.init(name: "actor", value: actor.wireFormat)]
			}
		}
	}
}

extension Lexicon.App.Bsky.Actor.GetProfile: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> { defaultErrors }
}

extension Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed: Mockable {
	public static func mock() -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		.init(
			did: Atproto.DID.mock().stringRepresentation,
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
