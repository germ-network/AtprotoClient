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
	public struct Follow: Atproto.Record {
		public struct Collection: Atproto.RecordType {
			static public var nsid: Atproto.NSID {
				.init(string: "app.bsky.graph.follow")
			}
			public init() {}
		}

		//periphery: ignore
		private(set) var nsid = Collection()

		public typealias Key = Atproto.TID
		//for encoding

		public let subject: Atproto.DID  // DID

		public let createdAt: Atproto.Datetime

		// Ignore `via` field

		package init(
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
