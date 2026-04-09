//
//  MockRepo.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/13/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

public actor MockRepo {
	typealias EncodedRecordKey = String

	static let knownRecords: [any AtprotoRecord.Type] = [
		Lexicon.App.Bsky.Actor.Profile.self,
		Lexicon.App.Bsky.Graph.Block.self,
		Lexicon.App.Bsky.Graph.Follow.self,
	]

	//to allow for storing records we don't know, we just store the encoded data
	private var untypedRepo: [Atproto.NSID: [EncodedRecordKey: Data]] = [:]

	public init() {}

	public func printPds() {
		print(untypedRepo)
	}
}

enum AtprotoMockAgentError: Error {
	case badParameters
}

// Get record
extension MockRepo {
	func getTypedRecord<R: AtprotoRecord>(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: CID?
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
		cid: CID?
	) throws -> [String: Any]? {
		guard let collectionContents = untypedRepo[collection] else {
			return nil
		}
		guard let record = collectionContents[encodedRkey] else {
			return nil
		}

		// TODO: Mock CID
		return [
			"uri": UUID().uuidString,
			"cid": cid?.string ?? CID.mock().string,
			"value": try JSONSerialization.jsonObject(with: record),
		]
	}

	func getRecordResponse(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: CID?
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
		if let limit {
			guard limit >= 1, limit <= 100 else {
				throw AtprotoMockAgentError.badParameters
			}
		}

		guard let collectionContents = untypedRepo[collection] else {
			return try JSONSerialization.data(withJSONObject: [
				"cursor": nil,
				"records": [],
			])
		}

		var records: [Any] = []

		// TODO: Implement cursor and CID
		for (encodedRkey, _) in collectionContents {
			let result = try getAnyRecord(
				collection: collection,
				encodedRkey: .init(string: encodedRkey),
				cid: nil
			)
			if let result {
				records.append(result)
			}

		}

		return try JSONSerialization.data(withJSONObject: [
			"cursor": nil,
			"records": records,
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
		let data = try JSONEncoder().encode(result)
		return .init(
			data: data,
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
		collection: String,
		rkey: String?,
		encodedRecord: Data
	) throws {
		untypedRepo[collection, default: [:]][rkey ?? UUID().uuidString] = encodedRecord
	}

	func putRecord(
		collection: String,
		rkey: String,
		encodedRecord: Data
	) throws {
		untypedRepo[collection, default: [:]][rkey] = encodedRecord
	}
}

extension MockRepo {
	func getGraph() throws -> (
		[Lexicon.App.Bsky.Graph.Follow], [Lexicon.App.Bsky.Graph.Block]
	) {
		let follows = try (untypedRepo[Lexicon.App.Bsky.Graph.Follow.nsid] ?? [:])
			.values
			.map {
				try JSONDecoder().decode(
					Lexicon.App.Bsky.Graph.Follow.self, from: $0)
			}

		let blocks = try (untypedRepo[Lexicon.App.Bsky.Graph.Block.nsid] ?? [:])
			.values
			.map {
				try JSONDecoder().decode(
					Lexicon.App.Bsky.Graph.Block.self, from: $0)
			}

		return (follows, blocks)
	}

	public func follow(did: Atproto.DID) throws {
		try putRecord(
			collection: Lexicon.App.Bsky.Graph.Follow.nsid,
			rkey: UUID().uuidString,
			encodedRecord: JSONEncoder()
				.encode(Lexicon.App.Bsky.Graph.Follow(subject: did))
		)
	}
}
