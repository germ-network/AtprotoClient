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

		public let createdAt: Atproto.Datetime

		// Ignore `via` field

		public init(
			subject: Atproto.DID,
			createdAt: Date = .now
		) {
			self.subject = subject
			self.createdAt = .init(date: createdAt)
		}

		enum CodingKeys: String, CodingKey {
			case nsid = "$type"
			case subject
			case createdAt
		}
	}
}

extension Lexicon.App.Bsky.Graph.Follow: AtprotoRecord {
	public static func mock() -> Lexicon.App.Bsky.Graph.Follow {
		.init(subject: .mock(), createdAt: .now)
	}
}
