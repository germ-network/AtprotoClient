//
//  Graph.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/24/26.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import Mockable

extension Lexicon.App.Bsky.Graph.Block: Mockable {
	public static func mock() -> AtprotoTypes.Lexicon.App.Bsky.Graph.Block {
		.init(subject: .mock(), createdAt: .now)
	}
}

extension Lexicon.App.Bsky.Graph.Follow: Mockable {
	public static func mock() -> Lexicon.App.Bsky.Graph.Follow {
		.init(subject: .mock())
	}
}
