//
//  BlockRecord.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 6/11/25.
//

import AtprotoTypes
import Foundation

extension Lexicon.App.Bsky.Graph {

	/// A record model for a block.
	///
	/// - Note: According to the AT Protocol specifications: "Record declaring a 'block'
	/// relationship against another account. NOTE: blocks are public in Bluesky; see
	/// blog posts for details."
	///
	/// - SeeAlso: This is based on the [`app.bsky.graph.block`][github] lexicon.
	///
	/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/app/bsky/graph/block.json
	public struct Block: Sendable, Codable {

		/// The identifier of the lexicon.
		///
		/// - Warning: The value must not change.
		public static let nsid: String = "app.bsky.graph.block"
		private(set) var nsid: Atproto.NSID = Self.nsid
		/// The decentralized identifier(DID) of the subject that has been blocked.
		///
		/// - Note: According to the AT Protocol specifications: "DID of the account to be blocked."
		public let subject: Atproto.DID

		/// The date and time the block record was created.
		public let createdAt: Date

		public init(subject: Atproto.DID, createdAt: Date) {
			self.subject = subject
			self.createdAt = createdAt
		}

		enum CodingKeys: String, CodingKey {
			case nsid = "$type"
			case subject
			case createdAt
		}
	}
}
