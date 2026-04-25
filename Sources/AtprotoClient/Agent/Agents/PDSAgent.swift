//
//  PDSAgent.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/30/26.
//

import AtprotoTypes
import Foundation

//has a default repo
extension Atproto {
	public protocol PDSAgent: Atproto.XRPC.Callable {
		var did: Atproto.DID { get }
	}
}

extension Atproto.PDSAgent {
	public func getRecord<R: Atproto.Record>(
		type: R.Type = R.self,
		rkey: R.Key,
		cid: Atproto.CID?
	) async throws -> R? {
		try await getRecord(
			parameters: .init(
				repo: .did(did),
				rkey: rkey,
				cid: cid
			)
		)
	}

	public func getProfile() async throws -> Lexicon.App.Bsky.Actor.Profile? {
		try await getRecord()
	}

	func listRecords<R: Atproto.Record>(
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) async throws -> ([R], String?) {
		let result = try await call(
			Lexicon.Com.Atproto.Repo.ListRecords<R>.self,
			parameters: .init(
				repo: .did(did),
				limit: limit,
				cursor: cursor,
				reverse: reverse
			),
		)
		let records = result.records.map { $0.value }
		return (records, result.cursor)
	}

	public func getBlob(
		cid: Atproto.CID,
	) async throws -> Data? {
		do {
			return try await call(
				Lexicon.Com.Atproto.Sync.GetBlob.self,
				parameters: .init(did: .did(did), cid: cid),
			)
		} catch Atproto.XRPC.ParseError.xrpcError(
			status: .badRequest,
			error: let errorObject
		)
			where errorObject.error == "BlobNotFound"
		{
			return nil
		}
	}
}
