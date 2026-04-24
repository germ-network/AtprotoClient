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
	public struct Profile: Sendable, Codable, Equatable {
		/// The identifier of the lexicon.
		///
		/// - Warning: The value must not change.
		//is "id" in the lexicon but avoid conflict with Swift id
		public static let nsid: Atproto.NSID = "app.bsky.actor.profile"
		//for encoding
		private(set) var nsid: Atproto.NSID = Self.nsid
		public typealias Key = Lexicon.LiteralSelfRecordKey

		/// Optional
		/// Small image to be displayed next to posts from account. AKA, 'profile picture'
		public let avatar: Atproto.Blob?

		/// Optional
		/// Larger horizontal image to display behind profile view.
		public let banner: Atproto.Blob?

		/// Optional
		/// An RFC 3339 formatted timestamp.
		public let createdAt: Atproto.Datetime

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
			avatar: Atproto.Blob?,
			banner: Atproto.Blob?,
			description: String?,
			displayName: String?,
			pronouns: String?,
			website: URL?
		) {
			self.avatar = avatar
			self.banner = banner
			self.description = description
			self.displayName = displayName
			self.pronouns = pronouns
			self.website = website
		}
	}
}

extension Lexicon.App.Bsky.Actor.Profile: AtprotoRecord {
	public static func mock() -> Lexicon.App.Bsky.Actor.Profile {
		.init(
			avatar: nil,
			banner: nil,
			createdAt: .init(date: .now),
			description: "Share what you want to, when you need to.",
			displayName: "Germ Network",
			pronouns: "they/them",
			website: nil
		)
	}
}
