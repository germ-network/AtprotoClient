//
//  Profile.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/3/26.
//

import AtprotoTypes
import Foundation

extension Lexicon.App.Bsky.Actor {
	/// For reading profile only. In order to write must implemented commented-out fields.
	/// https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.actor.profile/docs
	public struct Profile: Atproto.Record, Equatable {
		public struct Collection: Atproto.RecordType {
			static public var nsid: Atproto.NSID {
				.init(string: "app.bsky.actor.profile")
			}
			public init() {}
		}
		//for encoding
		//periphery: ignore
		private(set) var nsid = Collection()

		public typealias Key = Atproto.LiteralSelfRecordKey

		/// Optional
		/// Small image to be displayed next to posts from account. AKA, 'profile picture'
		public let avatar: Atproto.Primitive.Blob?

		/// Optional
		/// Larger horizontal image to display behind profile view.
		public let banner: Atproto.Primitive.Blob?

		/// Optional
		/// An RFC 3339 formatted timestamp.
		public let createdAt: Atproto.Datetime?

		/// Optional
		/// Free-form profile description text.
		public let description: String?

		/// Optional
		public let displayName: String?

		/// Optional
		// public let joinedViaStarterPack: Lexicon.Com.Atproto.Repo.StrongRef?

		/// Optional
		// public let labels: [Lexicon.Com.Atproto.Label.Defs.SelfLabels?]

		/// Optional
		// public let pinnedPost: Lexicon.Com.Atproto.Repo.StrongRef?

		/// Optional
		/// Free-form pronouns text
		public let pronouns: String?

		/// Optional
		/// A valid URI
		public let website: URL?

		enum CodingKeys: String, CodingKey {
			case nsid = "$type"
			case avatar
			case banner
			case createdAt
			case description
			case displayName
			case pronouns
			case website
		}

		public init(
			avatar: Atproto.Primitive.Blob?,
			banner: Atproto.Primitive.Blob?,
			createdAt: Date?,
			description: String?,
			displayName: String?,
			pronouns: String?,
			website: URL?
		) {
			self.avatar = avatar
			self.banner = banner
			self.createdAt = if let createdAt { .init(date: createdAt) } else { nil }
			self.description = description
			self.displayName = displayName
			self.pronouns = pronouns
			self.website = website
		}
	}
}
