//
//  Profile.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/3/26.
//

import AtprotoTypes
import Foundation

//this needs to be proxied to https://public.api.bsky.app
extension AtprotoAgent {
	public func authBskyProfileViewerState(
		for did: Atproto.DID
	) async throws -> Lexicon.App.Bsky.Actor.Defs.ViewerState {
		try await call(
			Lexicon.App.Bsky.Actor.GetProfile.self,
			parameters: .init(actor: .did(did))
		).viewer.tryUnwrap
	}
}
