//
//  Profile.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/3/26.
//

import AtprotoTypes
import Foundation

//this needs to be proxied to https://public.api.bsky.app
//reference for the endpoint: https://docs.bsky.app/docs/advanced-guides/api-directory#bluesky-services
extension AtprotoProxyAgent {
	public func authBskyProfileViewerState(
		for did: Atproto.DID
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ViewerState {
		try await call(
			Lexicon.App.Bsky.Actor.GetProfile.self,
			parameters: .init(actor: .did(did)),
			proxy: .init(
				did: .init(string: "did:web:api.bsky.app"),
				endpoint: "bsky_appview"
			)
		).viewer.tryUnwrap
	}
}
