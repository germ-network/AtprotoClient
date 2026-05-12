//
//  GetBlocks.swift
//  AtprotoClient
//
//  Created by Anna on 5/12/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

///https://docs.bsky.app/docs/api/app-bsky-graph-get-blocks
///https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.graph.getBlocks/docs
extension Lexicon.App.Bsky.Graph {
	public enum GetBlocks: Atproto.XRPC.Request {
		public struct Id: Atproto.XRPC.EndpointId {
			public static var nsid: Atproto.NSID {
				.init(string: "app.bsky.graph.getBlocks")
			}

			public init() {}
		}

		public static var outputEncoding: HTTPContentType {
			.json
		}

		public struct Parameters: QueryParametrizable {
			public let limit: Int?
			public let cursor: String?

			public init(
				limit: Int?,
				cursor: String?
			) {
				self.limit = Self.boundLimit(limit)
				self.cursor = cursor
			}

			private static func boundLimit(_ limit: Int?) -> Int? {
				guard let limit else {
					return nil
				}
				switch limit {
				case 100...:
					return 100
				case ...1:
					return 1
				default:
					return limit
				}
			}

			public func asQueryItems() -> [URLQueryItem] {
				var base: [URLQueryItem] = []
				if let limit {
					base.append(.init(name: "limit", value: limit.description))
				}
				if let cursor {
					base.append(.init(name: "cursor", value: cursor))
				}
				return base
			}
		}

		public struct Output: Sendable, Codable {
			public let cursor: String?
			public let blocks: [Lexicon.App.Bsky.Actor.Defs.ProfileView]

			public init(
				cursor: String?,
				blocks: [Lexicon.App.Bsky.Actor.Defs.ProfileView]
			) {
				self.cursor = cursor
				self.blocks = blocks
			}
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetBlocks: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> { defaultErrors }
}
