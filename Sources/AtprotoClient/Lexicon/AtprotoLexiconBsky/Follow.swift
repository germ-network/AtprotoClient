//
//  FollowRecord.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/28/25.
//

import AtprotoTypes
import Foundation

//https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.graph.follow/docs
extension Lexicon.App.Bsky.Graph {
	public struct Follow: Sendable, Codable {
		/// The identifier of the lexicon.
		///
		/// - Warning: The value must not change.
		//is "id" in the lexicon but avoid conflict with Swift id
		public static let nsid: Atproto.NSID = "app.bsky.graph.follow"
		public typealias Key = Atproto.TID
		//for encoding
		private(set) var nsid: Atproto.NSID = Self.nsid

		public let subject: Atproto.DID  // DID
		// Ignoring the createdAt field until we can easily decode
		// public let createdAt: Date

		// Ignore `via` field

		package init(subject: Atproto.DID) {
			self.subject = subject
		}

		enum CodingKeys: String, CodingKey {
			case nsid = "$type"
			case subject
		}
	}
}

extension Lexicon.App.Bsky.Graph.Follow: Atproto.Record {
	public static func mock() -> Lexicon.App.Bsky.Graph.Follow {
		.init(subject: .mock())
	}
}
