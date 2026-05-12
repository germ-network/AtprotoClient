//
//  GetFollows.swift
//  AtprotoClient
//
//  Created by Anna on 5/12/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

///https://docs.bsky.app/docs/api/app-bsky-graph-get-follows
///https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.graph.getFollows/docs
extension Lexicon.App.Bsky.Graph {
	public enum GetFollows: Atproto.XRPC.Request {
		public struct Id: Atproto.XRPC.EndpointId {
			public static var nsid: Atproto.NSID {
				.init(string: "app.bsky.graph.getFollows")
			}

			public init() {}
		}

		public static var outputEncoding: HTTPContentType {
			.json
		}

		public struct Parameters: QueryParametrizable {
			public let actor: LexiconString.AtIdentifier
			public let limit: Int?
			public let cursor: String?

			public init(
				actor: LexiconString.AtIdentifier,
				limit: Int?,
				cursor: String?
			) {
				self.actor = actor
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
				var base: [URLQueryItem] = [
					.init(name: "actor", value: actor.rawValue)
				]
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
			public let subject: Lexicon.App.Bsky.Actor.Defs.ProfileView
			public let cursor: String?
			public let follows: [Lexicon.App.Bsky.Actor.Defs.ProfileView]

			public init(
				subject: Lexicon.App.Bsky.Actor.Defs.ProfileView,
				cursor: String?,
				follows: [Lexicon.App.Bsky.Actor.Defs.ProfileView]
			) {
				self.subject = subject
				self.cursor = cursor
				self.follows = follows
			}
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetFollows: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> { defaultErrors }
}
