//
//  XRPCAuthCallable.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 4/3/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

//an implementation (e.g. auth'd PDS) can declare itself capable of authed requests
extension Atproto.XRPC {
	public protocol AuthCallable: Callable {
		var did: Atproto.DID { get }
	}
}

extension Atproto.XRPC.AuthCallable {
	public func createRecord<R: Atproto.Record>(
		_ record: R,
		rkey: R.Key? = nil,
		validate: Bool? = nil,
		swapCommit: Atproto.CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.CreateRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.CreateRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: rkey,
					record: record,
					validate: validate,
					swapCommit: swapCommit
				)
			),
		)
	}

	public func putRecord<R: Atproto.Record>(
		_: R.Type = R.self,
		input: Lexicon.Com.Atproto.Repo.PutRecord<R>.Input,
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: input,
		)
	}

	public func deleteRecord<R: Atproto.Record>(
	//allows for type inference when clear and explicit defn when not
		type: R.Type,
		rkey: R.Key,
		swapRecord: Atproto.CID? = nil,
		swapCommit: Atproto.CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.DeleteRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.DeleteRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: rkey,
					swapRecord: swapRecord,
					swapCommit: swapCommit,
				)
			),
		)
	}
}
