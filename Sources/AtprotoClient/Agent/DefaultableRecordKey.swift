//
//  DefaultableRecordKey.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/3/26.
//

import AtprotoTypes
import Foundation

extension PDSAgent {
	public func getRecord<R: Atproto.Record>(
		type: R.Type = R.self,
		cid: CID? = nil
	) async throws -> R? where R.Key: LexiconTypes.DefaultableRecordKey {
		try await getRecord(
			parameters: .init(
				repo: .did(did),
				rkey: .defaultValue(),
				cid: cid
			)
		)
	}
}

extension XRPCAuthCallable {
	public func createRecord<R>(
		_ record: R,
		validate: Bool? = nil,
		swapCommit: CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.CreateRecord<R>.Output
	where R.Key: LexiconTypes.DefaultableRecordKey {
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
		swapCommit: CID? = nil,
		swapRecord: CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.PutRecord<R>.Output
	where R.Key: LexiconTypes.DefaultableRecordKey {
		try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: .init(
				schema: .init(
					repo: .did(did),
					rkey: .defaultValue(),
					record: record,
					swapCommit: swapCommit,
					swapRecord: swapRecord
				)
			),
		)
	}

	public func deleteRecord<R: Atproto.Record>(
		//allows for type inference when clear and explicit defn when not
		type: R.Type = R.self,
		swapCommit: CID? = nil,
		swapRecord: CID? = nil,
	) async throws -> Lexicon.Com.Atproto.Repo.DeleteRecord<R>.Output
	where R.Key: LexiconTypes.DefaultableRecordKey {
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
