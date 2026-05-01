//
//  Resolver.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/18/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

extension Atproto {
	public protocol Resolver: Sendable {
		///like https://docs.bsky.app/docs/api/com-atproto-identity-resolve-handle
		///or compatible versions such as https://slingshot.microcosm.blue/#tag/comatproto-queries/GET/xrpc/com.atproto.identity.resolveHandle
		func resolve(handle: Handle) async throws -> DID?

		///equivalent to a plc query or did:web lookup
		///must always compare the did to the returned document's id and throw
		///if mismatched
		func resolve(did: DID) async throws -> DIDDocument?

		//we supply a default implementation of this
		//allows for the single request use of Slingshot's resolveMiniDoc
		func verifiedResolve(
			handle: Handle
		) async throws -> Atproto.DIDDocument.Verified?
	}
}

// Default implementation for verifiedResolve, can be overridden
extension Atproto.Resolver {
	public func verifiedResolve(
		handle: Atproto.Handle
	) async throws -> Atproto.DIDDocument.Verified? {
		guard let did = try await resolve(handle: handle) else {
			return nil
		}

		//if a did doc doesn't resolve it's an error
		return try await resolve(did: did).tryUnwrap
			.verified(expecting: handle, did: did)
	}

	public func verifiedResolve(
		atIdentifier: LexiconString.AtIdentifier
	) async throws -> Atproto.DIDDocument.Verified? {
		switch atIdentifier {
		case .handle(let handle):
			try await verifiedResolve(handle: handle)
		case .did(let did):
			try await resolve(did: did)?
				.verified { unverifiedHandle in
					let didDoc = try await resolve(handle: unverifiedHandle)
						.tryUnwrap
					return try .init(string: didDoc.identifier)
				}
		}
	}
}
