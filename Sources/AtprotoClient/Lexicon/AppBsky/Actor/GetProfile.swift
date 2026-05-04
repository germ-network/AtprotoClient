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
	public enum GetProfile: Atproto.XRPC.Request {
		public struct Id: Atproto.XRPC.EndpointId {
			public static var nsid: Atproto.NSID {
				.init(string: "app.bsky.actor.getProfile")
			}

			public init() {}
		}
		public typealias Output = Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed

		public static var outputEncoding: HTTPContentType {
			.json
		}

		public struct Parameters: QueryParametrizable {
			public let actor: LexiconString.AtIdentifier

			public init(actor: LexiconString.AtIdentifier) {
				self.actor = actor
			}

			public func asQueryItems() -> [URLQueryItem] {
				[.init(name: "actor", value: actor.rawValue)]
			}
		}
	}
}

extension Lexicon.App.Bsky.Actor.GetProfile: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> { defaultErrors }
}
