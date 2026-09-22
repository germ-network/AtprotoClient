//
//  BskyAppAgent.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP

extension Atproto.XRPC {
	//an agent (aka an app-view) that services the app.bsky.* application
	//e.g. https://api.blacksky.community or https://public.api.bsky.app
	public protocol BskyAppCallable: Atproto.XRPC.Callable {
	}
}

//An unauthenticated agent for the Bluesky public api
public struct BskyAppViewAgent {
	let serviceUrl: URL
	private let resourceFetcher: HTTPFetcher

	public init(
		serviceUrl: URL,
		resourceFetcher: HTTPFetcher
	) throws {
		self.serviceUrl = serviceUrl
		self.resourceFetcher = resourceFetcher
	}

	public static func blackskyAppView(resourceFetcher: HTTPFetcher) throws -> Self {
		try .init(
			serviceUrl: try URL(string: "https://api.blacksky.community").tryUnwrap,
			resourceFetcher: resourceFetcher
		)
	}

	public static func blueskyAppView(resourceFetcher: HTTPFetcher) throws -> Self {
		try .init(
			serviceUrl: try URL(string: "https://public.api.bsky.app").tryUnwrap,
			resourceFetcher: resourceFetcher
		)
	}
}

extension BskyAppViewAgent: Atproto.XRPC.BskyAppCallable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)

		return try await resourceFetcher.data(for: request)
	}
}

extension Atproto.XRPC.BskyAppCallable {
	public func bskyProfile(
		actor: LexiconString.AtIdentifier
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		try await call(
			Lexicon.App.Bsky.Actor.GetProfile.self,
			parameters: .init(actor: actor)
		)
	}

	/// `getProfile` declares no dedicated not-found error - a missing actor
	/// arrives as a 400 `InvalidRequest` whose message happens to be "Profile
	/// not found". Maps exactly that shape to `nil`; every other error
	/// (including other `InvalidRequest` messages, and a deactivated or
	/// suspended account's `AccountDeactivated`/`AccountTakedown`) rethrows.
	public func bskyProfileIfExists(
		actor: LexiconString.AtIdentifier
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed? {
		do {
			return try await bskyProfile(actor: actor)
		} catch Atproto.XRPC.ParseError.xrpcError(
			status: .badRequest,
			error: let error
		)
			where error.error == "InvalidRequest"
			&& error.message == "Profile not found"
		{
			return nil
		}
	}
}

extension Atproto.XRPC.BskyAppCallable {
	/// Drops every not-found subject and loses which ones they were - use
	/// ``relationshipLookup(actor:others:)`` to keep that information. Still
	/// throws `GetRelationships.Errors.tooManyOthersInput` above 30 subjects.
	public func getRelationships(
		actor: Atproto.DID,
		subjects: [Atproto.DID]
	) async throws -> [Lexicon.App.Bsky.Graph.Relationships] {
		let results = try await call(
			Lexicon.App.Bsky.Graph.GetRelationships.self,
			parameters: .init(actor: .did(actor), others: subjects.map { .did($0) })
		)
		assert(results.actor == actor)
		return results.relationships
			.compactMap { $0.asRelationships }
	}

	/// `others` deduped (preserving order) and chunked into requests of at
	/// most 30, the lexicon's `others.maxLength`, merging every chunk's
	/// result. Only `.relationship`
	/// entries for a requested DID count as found - an unrequested DID the
	/// server threw in is dropped, and `.notFoundActor` is never used to
	/// populate `found` (its `actor` can arrive in handle form, which can't
	/// be mapped back to the DID that was actually requested). Whatever
	/// wasn't found - whether the server said so explicitly (by DID or by
	/// handle) or simply omitted it - lands in `notFound`. See
	/// `GetRelationships.Lookup`'s doc for why this isn't an
	/// account-existence check.
	public func relationshipLookup(
		actor: Atproto.DID,
		others: [Atproto.DID]
	) async throws -> Lexicon.App.Bsky.Graph.GetRelationships.Lookup {
		let deduped = Self.dedupedPreservingOrder(others)
		guard !deduped.isEmpty else {
			return .init()
		}
		let requested = Set(deduped)

		var found: [Atproto.DID: Lexicon.App.Bsky.Graph.Relationships] = [:]
		for chunk in Self.chunked(
			deduped,
			intoSizeAtMost: Lexicon.App.Bsky.Graph.GetRelationships.Parameters.maxOthers
		) {
			let parameters = try Lexicon.App.Bsky.Graph.GetRelationships.Parameters(
				actor: .did(actor),
				others: chunk.map { .did($0) }
			)
			let output = try await call(
				Lexicon.App.Bsky.Graph.GetRelationships.self,
				parameters: parameters
			)
			guard output.actor == actor else {
				throw Lexicon.App.Bsky.Graph.GetRelationships.Errors.actorMismatch(
					requested: actor,
					returned: output.actor
				)
			}
			for entry in output.relationships {
				guard case .relationship(let relationship) = entry,
					requested.contains(relationship.did)
				else { continue }
				found[relationship.did] = relationship
			}
		}
		let notFound = deduped.filter { found[$0] == nil }
		return .init(found: found, notFound: notFound)
	}

	private static func dedupedPreservingOrder(_ dids: [Atproto.DID]) -> [Atproto.DID] {
		var seen = Set<Atproto.DID>()
		return dids.filter { seen.insert($0).inserted }
	}

	private static func chunked(
		_ dids: [Atproto.DID],
		intoSizeAtMost size: Int
	) -> [[Atproto.DID]] {
		stride(from: 0, to: dids.count, by: size).map {
			Array(dids[$0..<Swift.min($0 + size, dids.count)])
		}
	}
}

public enum BskyAppViewPublicSocialGraphs: Sendable {
	case follows
	case followers
}

extension Atproto.XRPC.BskyAppCallable {
	public func streamSocialGraphs(
		for actor: LexiconString.AtIdentifier,
		socialGraphType: BskyAppViewPublicSocialGraphs,
	) async throws -> AsyncThrowingStream<
		[Lexicon.App.Bsky.Actor.Defs.ProfileView], Error
	> {
		let (stream, continuation) = AsyncThrowingStream<
			[Lexicon.App.Bsky.Actor.Defs.ProfileView], Error
		>
		.makeStream(bufferingPolicy: .unbounded)

		Task {
			var cursor: String? = nil
			var fetchCount = 0
			do {
				repeat {
					let result:
						(
							profiles: [Lexicon.App.Bsky.Actor.Defs
								.ProfileView],
							cursor: String?
						) =
							try await getProfileBatch(
								for: actor,
								socialGraphType: socialGraphType,
								cursor: cursor
							)
					continuation.yield(result.profiles)
					cursor = result.cursor
					fetchCount += 1
				} while cursor != nil && fetchCount < ATProtoConstants.maxFetches
				continuation.finish()
			} catch {
				continuation.finish(throwing: error)
			}
		}
		return stream
	}

	private func getProfileBatch(
		for actor: LexiconString.AtIdentifier,
		socialGraphType: BskyAppViewPublicSocialGraphs,
		cursor: String?
	) async throws -> (
		[Lexicon.App.Bsky.Actor.Defs.ProfileView], String?
	) {
		switch socialGraphType {
		case .follows:
			try await call(
				Lexicon.App.Bsky.Graph.GetFollows.self,
				parameters: .init(
					actor: actor,
					limit: 100,
					cursor: cursor
				)
			).profileBatch
		case .followers:
			try await call(
				Lexicon.App.Bsky.Graph.GetFollowers.self,
				parameters: .init(
					actor: actor,
					limit: 100,
					cursor: cursor
				)
			).profileBatch
		}
	}
}

extension Lexicon.App.Bsky.Graph.GetFollows.Output {
	var profileBatch: ([Lexicon.App.Bsky.Actor.Defs.ProfileView], String?) {
		(follows, cursor)
	}
}

extension Lexicon.App.Bsky.Graph.GetFollowers.Output {
	var profileBatch: ([Lexicon.App.Bsky.Actor.Defs.ProfileView], String?) {
		(followers, cursor)
	}
}
