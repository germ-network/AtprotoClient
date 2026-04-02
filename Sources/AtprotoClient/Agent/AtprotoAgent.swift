//
//  AtprotoAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/23/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

/// Agent
///
/// All fetching should be done through an agent
///
/// AtprotoOAuthAgent conforms to AtprotoAgent and uses OAuth functionality for authed calls
/// AtprotoMockAgent conforms to AtprotoAgent and returns mocks for authed and unauthed calls
///  - Should also properly mock a server instance
/// UnauthenticatedAtprotoAgent conforms to AtprotoAgent and throws on authed calls
///
/// Have a method on it that declares whether or not it can do auth
///
public protocol AtprotoAgent: Sendable {
	func response(_ requestComponents: XRPCRequestComponents) async throws
		-> HTTPDataResponse
}

extension AtprotoAgent {
	public func getRecord<R: AtprotoRecord>(
		parameters: Lexicon.Com.Atproto.Repo.GetRecord<R>.Parameters,
	) async throws -> R? {
		do {
			return try await call(
				Lexicon.Com.Atproto.Repo.GetRecord<R>.self,
				parameters: parameters,
			).value
			//this is per the api docs, not the lexicon
		} catch ParseXRPCError.xrpcError(status: .badRequest, error: let errorObject)
			where errorObject.error == "RecordNotFound"
		{
			return nil
		}
	}

	func listRecords<R: AtprotoRecord>(
		parameters: Lexicon.Com.Atproto.Repo.ListRecords<R>.Parameters,
	) async throws -> ([R], String?) {
		let result = try await call(
			Lexicon.Com.Atproto.Repo.ListRecords<R>.self,
			parameters: parameters,
		)
		let records = result.records.map { $0.value }
		return (records, result.cursor)
	}

	public func stream<R: AtprotoRecord>(
		//allows for type inference when clear and explicit defn when not
		recordType: R.Type = R.self,
		did: Atproto.DID,
	) async throws -> AsyncThrowingStream<[R], Error> {
		let (stream, continuation) = AsyncThrowingStream<[R], Error>
			.makeStream(bufferingPolicy: .unbounded)

		Task {
			var cursor: String? = nil
			var fetchCount = 0
			do {
				repeat {
					let result: (records: [R], cursor: String?) =
						try await listRecords(
							parameters: .init(
								repo: .did(did),
								limit: 100,  // max
								cursor: cursor,
								reverse: nil
							)
						)
					continuation.yield(result.records)
					cursor = result.cursor
					fetchCount += 1
				} while cursor != nil && fetchCount < ATProtoConstants.maxFetches
				continuation.finish()
			} catch {
				continuation.finish(throwing: error)
			}
		}
		return stream
	}

	public func getBlob(
		parameters: Lexicon.Com.Atproto.Sync.GetBlob.Parameters,
	) async throws -> Data? {
		do {
			return try await call(
				Lexicon.Com.Atproto.Sync.GetBlob.self,
				parameters: parameters,
			)
		} catch ParseXRPCError.xrpcError(status: .badRequest, error: let errorObject)
			where errorObject.error == "BlobNotFound"
		{
			return nil
		}
	}

	public func put<R: AtprotoRecord>(
		_ recordType: R.Type,
		input: Lexicon.Com.Atproto.Repo.PutRecord<R>.Input,
	) async throws {
		let _ = try await call(
			Lexicon.Com.Atproto.Repo.PutRecord<R>.self,
			input: input,
		)
	}
}
