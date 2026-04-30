//
//  DefaultableRecordKey.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/3/26.
//

import AtprotoTypes
import Foundation

extension Atproto.PDSAgent {
	public func getRecord<R: Atproto.Record>(
		_: R.Type = R.self,
		cid: Atproto.CID? = nil
	) async throws -> R? where R.Key: Atproto.DefaultableRecordKey {
		try await getRecord(
			parameters: .init(
				repo: .did(did),
				rkey: .defaultValue(),
				cid: cid
			)
		)
	}
}

extension Atproto.XRPC.AuthCallable {
	public func createRecord<R>(
		_ record: R,
		validate: Bool? = nil,
		swapCommit: Atproto.CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.CreateRecord<R>.Output
	where R.Key: Atproto.DefaultableRecordKey {
		try await call(
			Lexicon.Com.Atproto.Repo.CreateRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: .defaultValue(),
					record: record,
					validate: validate,
					swapCommit: swapCommit

				)
			),
		)
	}

	public func putRecord<R: Atproto.Record>(
		_ record: R,
		validate: Bool? = nil,
		swapCommit: Atproto.CID? = nil,
		swapRecord: Atproto.CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecord<R>.Output
	where R.Key: Atproto.DefaultableRecordKey {
		try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: .defaultValue(),
					record: record,
					validate: validate,
					swapCommit: swapCommit,
					swapRecord: swapRecord
				)
			),
		)
	}

	public func deleteRecord<R: Atproto.Record>(
		//allows for type inference when clear and explicit defn when not
		_: R.Type = R.self,
		swapCommit: Atproto.CID? = nil,
		swapRecord: Atproto.CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.DeleteRecord<R>.Output
	where R.Key: Atproto.DefaultableRecordKey {
		try await call(
			Lexicon.Com.Atproto.Repo.DeleteRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: .defaultValue(),
					swapRecord: swapRecord,
					swapCommit: swapCommit,
				)
			),
		)
	}
}
