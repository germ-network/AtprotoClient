//
//  MockRepo.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/13/26.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import GermConvenience

public actor MockRepo {
	typealias EncodedRecordKey = String

	static let knownRecords: [any Atproto.Record.Type] = [
		Lexicon.App.Bsky.Actor.Profile.self,
		Lexicon.App.Bsky.Graph.Block.self,
		Lexicon.App.Bsky.Graph.Follow.self,
	]

	//to allow for storing records we don't know, we just store the encoded data
	private var untypedRepo: [Atproto.NSID: [EncodedRecordKey: Data]]

	//remainders from prior listRecords pages, keyed by an opaque UUID cursor
	typealias Cursor = UUID
	private var paginationCache: [UUID: [(EncodedRecordKey, Data)]] = [:]

	public init(bskyProfile: Lexicon.App.Bsky.Actor.Profile? = nil) throws {
		guard let bskyProfile else {
			untypedRepo = [:]
			return
		}

		let encoded = try JSONEncoder().encode(bskyProfile)
		untypedRepo = [
			Lexicon.App.Bsky.Actor.Profile.Collection.nsid:
				[Atproto.LiteralSelfRecordKey().rawValue: encoded]
		]

	}

	public func printPds() {
		print(untypedRepo)
	}

	enum Errors: Error {
		case badParameters
		case cursorNotFound
	}
}

extension MockRepo.Errors: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .badParameters: "bad parameters"
		case .cursorNotFound: "cursor not found"
		}
	}
}

// Get record
extension MockRepo {
	func getTypedRecord<R: Atproto.Record>(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: Atproto.CID?
	) throws -> R? {
		let dict = try getAnyRecord(
			collection: collection,
			encodedRkey: encodedRkey,
			cid: cid
		)

		guard let dict else {
			return nil
		}

		let anyType = try dict["value"].tryUnwrap
		let encoded = try JSONSerialization.data(withJSONObject: anyType, options: [])

		return try JSONDecoder().decode(R.self, from: encoded)
	}

	func getAnyRecord(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: Atproto.CID?
	) throws -> [String: Any]? {
		guard let collectionContents = untypedRepo[collection] else {
			return nil
		}
		guard let record = collectionContents[encodedRkey] else {
			return nil
		}

		// TODO: Mock CID
		return [
			"uri": "at://did:web:example.com/\(collection)/\(encodedRkey)",
			"cid": Atproto.CID.mock().string,
			"value": try JSONSerialization.jsonObject(with: record),
		]
	}

	func getRecordResponse(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: Atproto.CID?
	) throws -> HTTPDataResponse {
		let resultObject = try getAnyRecord(
			collection: collection,
			encodedRkey: encodedRkey,
			cid: cid
		)

		guard let resultObject else {
			return try .mock(error: "RecordNotFound", status: 400)
		}
		return .init(
			data: try JSONSerialization.data(withJSONObject: resultObject),
			response: .init(
				status: .ok,
				headerFields: .init(
					[
						.init(
							name: .contentType,
							value: HTTPContentType.json.rawValue)
					]
				)
			)
		)
	}

	//type-erased GetRecord
	struct MockGetRecordOutput: Encodable {
		let uri: String
		let cid: String
		let value: String
	}
}

// List records
extension MockRepo {
	func listRecords(
		collection: Atproto.NSID,
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) throws -> Data {
		let pageSize: Int =
			if let limit, (1...100).contains(limit) {
				limit
			} else {
				50
			}

		let pending: [(EncodedRecordKey, Data)]
		if let cursor {

			guard let uuidCursor = UUID(uuidString: cursor),
				let cached = paginationCache.removeValue(forKey: uuidCursor)
			else {
				throw Errors.cursorNotFound
			}
			pending = cached
		} else {
			guard let collectionContents = untypedRepo[collection] else {
				return try JSONSerialization.data(withJSONObject: [
					"cursor": nil,
					"records": [],
				])
			}

			pending = Array(collectionContents)
		}

		let page = Array(
			try pending.prefix(pageSize)
				.map { (key, encodedRecord) in
					[
						"uri":
							"at://did:web:example.com/\(collection)/\(key)",
						"cid": Atproto.CID.mock().string,
						"value":
							try JSONSerialization
							.jsonObject(with: encodedRecord),
					]
				}
		)
		let remainder = Array(pending.dropFirst(pageSize))

		let nextCursor: UUID?
		if remainder.isEmpty {
			nextCursor = nil
		} else {
			let newCursor = UUID()
			paginationCache[newCursor] = remainder
			nextCursor = newCursor
		}

		return try JSONSerialization.data(withJSONObject: [
			"cursor": nextCursor?.uuidString as Any,
			"records": page,
		])
	}

	func listRecordsResponse(
		collection: Atproto.NSID,
		limit: String?,
		cursor: String?,
		reverse: String?
	) throws -> HTTPDataResponse {
		let limitInt: Int? =
			if let limit {
				Int(limit)
			} else {
				nil
			}
		let reverseBool: Bool? =
			if let reverse {
				Bool(reverse)
			} else {
				nil
			}
		let result = try listRecords(
			collection: collection,
			limit: limitInt,
			cursor: cursor,
			reverse: reverseBool
		)

		return .init(
			data: result,
			response: .init(
				status: .ok,
				headerFields: .init(
					[
						.init(
							name: .contentType,
							value: HTTPContentType.json.rawValue
						)
					]
				)
			)
		)
	}
}

extension MockRepo {
	func createRecord(
		collection: Atproto.NSID,
		rkey: EncodedRecordKey?,
		encodedRecord: Data
	) throws {
		untypedRepo[collection, default: [:]][rkey ?? UUID().uuidString] = encodedRecord
	}

	func putRecord(
		collection: Atproto.NSID,
		rkey: EncodedRecordKey,
		encodedRecord: Data
	) throws {
		untypedRepo[collection, default: [:]][rkey] = encodedRecord
	}

	func deleteRecord(
		collection: Atproto.NSID,
		rkey: EncodedRecordKey
	) throws {
		untypedRepo[collection]?[rkey] = nil
	}
}

extension MockRepo {
	func getGraph() -> (
		[Lexicon.App.Bsky.Graph.Follow], [Lexicon.App.Bsky.Graph.Block]
	) {
		//Best-effort decode: skip any record that doesn't parse as its type rather
		//than failing the whole read on one bad/foreign record (matches `unfollow`).
		let follows =
			(untypedRepo[Lexicon.App.Bsky.Graph.Follow.Collection.nsid] ?? [:])
			.values
			.compactMap {
				try? JSONDecoder().decode(
					Lexicon.App.Bsky.Graph.Follow.self, from: $0)
			}

		let blocks =
			(untypedRepo[Lexicon.App.Bsky.Graph.Block.Collection.nsid] ?? [:])
			.values
			.compactMap {
				try? JSONDecoder().decode(
					Lexicon.App.Bsky.Graph.Block.self, from: $0)
			}

		return (follows, blocks)
	}

	public func follow(did: Atproto.DID) throws {
		try putRecord(
			collection: Lexicon.App.Bsky.Graph.Follow.Collection.nsid,
			rkey: UUID().uuidString,
			encodedRecord: JSONEncoder()
				.encode(Lexicon.App.Bsky.Graph.Follow(subject: did))
		)
	}

	public func block(did: Atproto.DID) throws {
		try putRecord(
			collection: Lexicon.App.Bsky.Graph.Block.Collection.nsid,
			rkey: UUID().uuidString,
			encodedRecord: JSONEncoder()
				.encode(Lexicon.App.Bsky.Graph.Block(subject: did))
		)
	}

	//Remove every follow record whose subject is `did` (the inverse of `follow`).
	//A no-op if none exist. Decoding is best-effort: a record that doesn't parse as a Follow
	//can't be the one we're removing, and must not abort the removal of the ones
	//that do — so skip it rather than throw.
	public func unfollow(did: Atproto.DID) {
		let collection = Lexicon.App.Bsky.Graph.Follow.Collection.nsid
		let records = untypedRepo[collection] ?? [:]
		for (rkey, encoded) in records {
			guard
				let follow = try? JSONDecoder()
					.decode(Lexicon.App.Bsky.Graph.Follow.self, from: encoded),
				follow.subject == did
			else { continue }
			untypedRepo[collection]?[rkey] = nil
		}
	}
}
