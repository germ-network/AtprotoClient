//
//  AppBskyGraphGetRelationships.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/13/26.
//

import AtprotoClient
import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import Mockable

extension Lexicon.App.Bsky.Graph.GetRelationships.Output: Mockable {
	static public func mock() -> Lexicon.App.Bsky.Graph.GetRelationships.Output {
		.init(actor: .mock(), relationships: [])
	}
}
