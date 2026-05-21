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
}

extension Lexicon.App.Bsky.Graph.GetRelationships: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(
			["ActorNotFound"]
		)
	}
}
