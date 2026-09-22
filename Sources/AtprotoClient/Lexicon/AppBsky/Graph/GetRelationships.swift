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
					// The lexicon declares others.maxLength: 30, so exactly 30
					// is valid - only 31+ is too many.
					guard others.count <= Self.maxOthers else {
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

		public enum Result: LexiconUnion {
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

			public static var members:
				[AtprotoTypes.Atproto.Ref: any AtprotoTypes.Atproto.Schema.Type]
			{
				[
					Relationships.ref: Relationships.self,
					NotFoundActor.ref: NotFoundActor.self,
				]
			}

			public init(object: any Codable) throws {
				if let relationships = object as? Relationships {
					self = .relationship(relationships)
				} else if let notFound = object as? NotFoundActor {
					self = .notFoundActor(notFound)
				} else {
					throw LexionUnionError.unknownObject
				}
			}

			//LexiconUnion provides decode
			public func encode(to encoder: any Encoder) throws {
				var container = encoder.singleValueContainer()
				switch self {
				case .relationship(let relationships):
					try container.encode(relationships)
				case .notFoundActor(let notFoundActor):
					try container.encode(notFoundActor)
				}
			}
		}

		/// Found/not-found subjects from ``Atproto.XRPC.BskyAppCallable/relationshipLookup(actor:others:)``,
		/// which - unlike ``Atproto.XRPC.BskyAppCallable/getRelationships(actor:subjects:)`` -
		/// keeps track of which requested subjects weren't found.
		///
		/// `found`/`notFound` isn't an account-existence check: the AppView
		/// returns a `#relationship` entry for any well-formed DID, whether or
		/// not the account exists, so a nonexistent `did:plc` still lands in
		/// `found`. `notFound` only covers what the server explicitly reported
		/// via `notFoundActor` (in practice, for a handle that doesn't
		/// resolve) or omitted outright. Callers that need to know whether an
		/// account actually exists should use
		/// ``Atproto.XRPC.BskyAppCallable/bskyProfileIfExists(actor:)``.
		public struct Lookup: Sendable {
			public var found: [Atproto.DID: Relationships]
			public var notFound: [Atproto.DID]

			public init(
				found: [Atproto.DID: Relationships] = [:],
				notFound: [Atproto.DID] = []
			) {
				self.found = found
				self.notFound = notFound
			}
		}

		public enum Errors: Error, Equatable, Sendable {
			case tooManyOthersInput
			/// A chunked request's response named a different `actor` than the
			/// one requested.
			case actorMismatch(requested: Atproto.DID, returned: Atproto.DID)
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetRelationships.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .tooManyOthersInput:
			"Too many others input"
		case .actorMismatch(let requested, let returned):
			"getRelationships returned actor \(returned.rawValue), requested \(requested.rawValue)"
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
