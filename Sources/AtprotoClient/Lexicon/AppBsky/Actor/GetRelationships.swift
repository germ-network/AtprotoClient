//
//  GetRelationships.swift
//  AppCoreLogic
//
//  Created by Mark @ Germ on 4/3/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

//https://docs.bsky.app/docs/api/app-bsky-graph-get-relationships
//https://lexicon.garden/lexicon/did:plc:4v4y5r3lwsbtmsxhile2ljac/app.bsky.graph.getRelationships
extension Lexicon.App.Bsky.Graph {
	public enum GetRelationships: Atproto.XRPC.Request {
		public struct Id: Atproto.XRPC.EndpointId {
			public static var nsid: Atproto.NSID {
				.init(string: "app.bsky.graph.getRelationships")
			}

			public init() {}
		}
		public static let outputEncoding: HTTPContentType = .json

		public struct Parameters: QueryParametrizable {

			let actor: LexiconString.AtIdentifier
			let others: [LexiconString.AtIdentifier]?  //maxlength 30
			static let maxOthers = 30

			public init(
				actor: LexiconString.AtIdentifier,
				others: [LexiconString.AtIdentifier]?
			) throws {
				if let others {
					guard others.count < Self.maxOthers else {
						throw Errors.tooManyOthersInput
					}
				}
				self.actor = actor
				self.others = others
			}

			public func asQueryItems() -> [URLQueryItem] {
				[URLQueryItem(name: "actor", value: actor.rawValue)]
					+ (others ?? [])
					.map {
						.init(name: "others", value: $0.rawValue)
					}
			}
		}

		public struct Output: Sendable, Codable {
			public let actor: Atproto.DID
			public let relationships: [Result]

			public init(actor: Atproto.DID, relationships: [Result]) {
				self.actor = actor
				self.relationships = relationships
			}
		}

		public enum Result: Codable, Sendable {
			case relationship(Relationships)
			case notFoundActor(NotFoundActor)

			public var asRelationships: Relationships? {
				switch self {
				case .relationship(let value):
					value
				case .notFoundActor:
					nil
				}
			}

			public init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()

				if let value = try? container.decode(Relationships.self) {
					self = .relationship(value)
				} else {
					let value = try container.decode(NotFoundActor.self)
					self = .notFoundActor(value)
				}
			}
		}

		enum Errors: LocalizedError {
			case tooManyOthersInput

			var errorDescription: String? {
				switch self {
				case .tooManyOthersInput:
					"Too many others input"
				}
			}
		}
	}

	public struct Relationships: Codable, Sendable {
		public let did: Atproto.DID
		public let blocking: Atproto.ATURI?
		public let blockedBy: Atproto.ATURI?
		public let following: Atproto.ATURI?
		public let followedBy: Atproto.ATURI?
		public let blockedByList: Atproto.ATURI?
		public let blockingbyList: Atproto.ATURI?

		public init(
			did: Atproto.DID,
			blocking: Atproto.ATURI?,
			blockedBy: Atproto.ATURI?,
			following: Atproto.ATURI?,
			followedBy: Atproto.ATURI?,
			blockedByList: Atproto.ATURI?,
			blockingbyList: Atproto.ATURI?
		) {
			self.did = did
			self.blocking = blocking
			self.blockedBy = blockedBy
			self.following = following
			self.followedBy = followedBy
			self.blockedByList = blockedByList
			self.blockingbyList = blockingbyList
		}
	}

	public struct NotFoundActor: Codable, Sendable {
		public let actor: LexiconString.AtIdentifier
		var notFound: Bool = true

		public init(actor: LexiconString.AtIdentifier) {
			self.actor = actor
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetRelationships: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(
			["ActorNotFound"]
		)
	}
}
