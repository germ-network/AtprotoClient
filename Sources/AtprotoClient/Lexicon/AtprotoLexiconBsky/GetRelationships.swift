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
	public enum GetRelationships: XRPCRequest {
		public static var nsid: Atproto.NSID { "app.bsky.graph.getRelationships" }
		public static let outputEncoding: HTTPContentType = .json

		public struct Parameters: QueryParametrizable {

			let actor: AtIdentifier
			let others: [AtIdentifier]?  //maxlength 30
			static let maxOthers = 30

			public init(actor: AtIdentifier, others: [AtIdentifier]?) throws {
				if let others {
					guard others.count < Self.maxOthers else {
						throw Errors.tooManyOthersInput
					}
				}
				self.actor = actor
				self.others = others
			}

			public func asQueryItems() -> [URLQueryItem] {
				[URLQueryItem(name: "actor", value: actor.wireFormat)]
					+ (others ?? [])
					.map {
						.init(name: "others", value: $0.wireFormat)
					}
			}
		}

		public struct Output: Sendable, Decodable {
			let actor: Atproto.DID
			let relationships: [Result]
		}

		enum Result: Decodable {
			case relationship(Relationships)
			case notFoundActor(NotFoundActor)

			init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()

				if let value = try? container.decode(Relationships.self) {
					self = .relationship(value)
				} else {
					let value = try container.decode(NotFoundActor.self)
					self = .notFoundActor(value)
				}
			}
		}

		enum Errors: Error {
			case tooManyOthersInput
		}
	}

	struct Relationships: Decodable {
		let did: Atproto.DID
		let blocking: Atproto.ATURI?
		let blockedBy: Atproto.ATURI?
		let following: Atproto.ATURI?
		let followedBy: Atproto.ATURI?
		let blockedByList: Atproto.ATURI?
		let blockingbyList: Atproto.ATURI?
	}

	struct NotFoundActor: Decodable {
		let actor: AtIdentifier
		var notFound: Bool = true
	}
}

extension Lexicon.App.Bsky.Graph.GetRelationships: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(
			["ActorNotFound"]
		)
	}
}

extension Lexicon.App.Bsky.Graph.GetRelationships.Output: Mockable {
	static public func mock() -> Lexicon.App.Bsky.Graph.GetRelationships.Output {
		.init(actor: .mock(), relationships: [])
	}
}

extension Lexicon.App.Bsky.Graph.GetRelationships.Errors: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .tooManyOthersInput:
			"Too many others input"
		}
	}
}
