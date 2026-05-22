//
//  Defs.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 5/20/26.
//

import AtprotoTypes
import Foundation

extension Lexicon.App.Bsky.Graph {
	public struct Relationships: Atproto.Schema {
		public static var ref: Atproto.Ref {
			.init(string: "app.bsky.graph.defs#relationship")
		}
		//for encoding
		private(set) var ref: Atproto.Ref? = ref
		public let did: Atproto.DID
		public let blocking: Atproto.ATURI?
		public let blockedBy: Atproto.ATURI?
		public let following: Atproto.ATURI?
		public let followedBy: Atproto.ATURI?
		public let blockedByList: Atproto.ATURI?
		public let blockingbyList: Atproto.ATURI?

		enum CodingKeys: String, CodingKey {
			case ref = "$type"
			case did
			case blocking
			case blockedBy
			case following
			case followedBy
			case blockedByList
			case blockingbyList
		}

		public init(
			did: Atproto.DID,
			blocking: Atproto.ATURI?,
			blockedBy: Atproto.ATURI?,
			following: Atproto.ATURI?,
			followedBy: Atproto.ATURI?,
			blockedByList: Atproto.ATURI?,
			blockingbyList: Atproto.ATURI?
		) {
			self.did = did
			self.blocking = blocking
			self.blockedBy = blockedBy
			self.following = following
			self.followedBy = followedBy
			self.blockedByList = blockedByList
			self.blockingbyList = blockingbyList
		}
	}

	public struct NotFoundActor: Atproto.Schema {
		public static var ref: Atproto.Ref {
			.init(string: "app.bsky.graph.defs#notFoundActor")
		}

		//for encoding
		private(set) var ref: Atproto.Ref? = ref
		public let actor: LexiconString.AtIdentifier
		var notFound: Bool = true

		public init(actor: LexiconString.AtIdentifier) {
			self.actor = actor
		}

		enum CodingKeys: String, CodingKey {
			case ref = "$type"
			case actor
			case notFound
		}
	}
}
