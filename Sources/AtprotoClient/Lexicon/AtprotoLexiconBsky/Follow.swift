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
		private(set) var nsid = Collection()

		public typealias Key = Atproto.TID
		//for encoding

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
