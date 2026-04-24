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
public protocol XRPCAuthCallable: XRPCCallable {
	var did: Atproto.DID { get }
}

extension XRPCAuthCallable {
	public func createRecord<R: AtprotoRecord>(
		_ record: R,
		rkey: R.Key? = nil,
		validate: Bool? = nil,
		swapCommit: CID? = nil,
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

	public func putRecord<R: AtprotoRecord>(
		type: R.Type = R.self,
		input: Lexicon.Com.Atproto.Repo.PutRecord<R>.Input,
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecord<R>.Output {
		try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: input,
		)
	}

	public func deleteRecord<R: AtprotoRecord>(
		type: R.Type,
		rkey: R.Key,
		swapRecord: CID? = nil,
		swapCommit: CID? = nil,
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
