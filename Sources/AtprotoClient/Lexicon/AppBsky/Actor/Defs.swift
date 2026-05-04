//
//  ProfileAuthedMetadata.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 9/24/25.
//

import AtprotoTypes
import Foundation

extension Lexicon.App.Bsky.Actor.Defs {

	/// A definition model for a profile view based on profileViewDetailed.
	///
	/// - SeeAlso: This is based on the [`app.bsky.actor.defs`][github] lexicon.
	///
	/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/app/bsky/actor/defs.json
	///
	//TODO: finish te remaining defs objects
	public struct ProfileViewDetailed: Sendable, Codable {

		//required
		public let did: Atproto.DID
		public let handle: Atproto.Handle

		public let displayName: String?
		public let description: String?
		public let pronouns: String?
		public let website: URL?
		public let avatar: URL?
		public let banner: URL?

		public let followersCount: Int?
		public let followsCount: Int?

		public let postsCount: Int?

		//public let associated: ProfileAssociated?
		//public let joinedViaStarterPack: JoinedViaStarterPack?

		public let indexedAt: LexiconString.Datetime?
		public let createdAt: LexiconString.Datetime?

		public let viewer: ViewerState?

		//public let labels: [Label]
		//public let pinnedPost: StrongRef
		//public let verification: VerificationState
		//public let status: StatusView
		//public let debug

		public init(
			did: Atproto.DID,
			handle: Atproto.Handle,
			displayName: String?,
			description: String?,
			pronouns: String?,
			website: URL?,
			avatar: URL?,
			banner: URL?,
			followersCount: Int?,
			followsCount: Int?,
			postsCount: Int?,
			indexedAt: LexiconString.Datetime?,
			createdAt: LexiconString.Datetime?,
			viewer: ViewerState?
		) {
			self.did = did
			self.handle = handle
			self.displayName = displayName
			self.description = description
			self.pronouns = pronouns
			self.website = website
			self.avatar = avatar
			self.banner = banner
			self.followersCount = followersCount
			self.followsCount = followsCount
			self.postsCount = postsCount
			self.indexedAt = indexedAt
			self.createdAt = createdAt
			self.viewer = viewer
		}

	}

	/// A definition model for an actor viewer state.
	///
	/// - Note: From the AT Protocol specification: "Metadata about the requesting account's
	/// relationship with the subject account. Only has meaningful content for authed requests."
	///
	/// - SeeAlso: This is based on the [`app.bsky.actor.defs`][github] lexicon.
	///
	/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/app/bsky/actor/defs.json
	///
	///TODO: match the lexicon def
	public struct ViewerState: Sendable, Codable {

		/// Indicates whether the requesting account has been muted by the subject
		/// account. Optional.
		public let muted: Bool?

		/// An array of lists that the subject account is muted by.
		//		public let mutedByArray: AppBskyLexicon.Graph.ListViewBasicDefinition?

		/// Indicates whether the authed user has been blocked by the account requested. Optional.
		public let blockedBy: Bool?

		/// A URI which indicates the authed user is blocking the account requested.
		public let blocking: Atproto.ATURI?

		/// An array of the subject account's lists.
		//		public let blockingByArray: AppBskyLexicon.Graph.ListViewBasicDefinition?

		/// A URI which indicates the authed user is following the account requested.
		public let following: Atproto.ATURI?

		/// A URI which indicates the authed user is being followed by the account requested.
		public let followedBy: Atproto.ATURI?

		/// An array of mutual followers. Optional.
		///
		/// - Note: According to the AT Protocol specifications: "The subject's followers whom you
		/// also follow."
		//		public let knownFollowers: KnownFollowers?

		public init(
			muted: Bool?,
			blockedBy: Bool?,
			blocking: Atproto.ATURI?,
			following: Atproto.ATURI?,
			followedBy: Atproto.ATURI?
		) {
			self.muted = muted
			self.blockedBy = blockedBy
			self.blocking = blocking
			self.following = following
			self.followedBy = followedBy
		}
	}
}
