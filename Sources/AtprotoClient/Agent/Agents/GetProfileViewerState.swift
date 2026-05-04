//
//  GetProfileViewerState.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/3/26.
//

import AtprotoTypes
import Foundation

//this needs to be proxied to https://public.api.bsky.app
//reference for the endpoint: https://docs.bsky.app/docs/advanced-guides/api-directory#bluesky-services
extension Atproto.XRPC.ProxyCallable {
	public func authBskyProfile(
		for did: Atproto.DID
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ProfileViewDetailed {
		try await call(
			Lexicon.App.Bsky.Actor.GetProfile.self,
			parameters: .init(actor: .did(did)),
			proxy: .bskyAppView
		)
	}
}

extension Atproto.Service {
	public static var bskyAppView: Self {
		get throws {
			.init(
				did: try .init(string: "did:web:api.bsky.app"),
				endpoint: "bsky_appview"
			)
		}
	}
}
