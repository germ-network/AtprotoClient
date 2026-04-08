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

	// Might want to check that the appropriate AtprotoRecord type is stored in a given NSID collection
	//to allow for storing records we don't know, we just store the encoded data
	private var repo: [Atproto.NSID: [EncodedRecordKey: Data]] = [:]

	public init() {}

	public func printPds() {
		print(repo)
	}
}

enum AtprotoMockAgentError: Error {
	case badParameters
}

// Get record
extension MockRepo {
	func getRecord(
		collection: Atproto.NSID,
		encodedRkey: EncodedRecordKey,
		cid: CID?
	) throws -> [String: Any] {
		guard let collectionContents = repo[collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let record = collectionContents[encodedRkey] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
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
	) throws -> GermConvenience.HTTPDataResponse {
		let resultObject = try getRecord(
			collection: collection,
			encodedRkey: encodedRkey,
			cid: cid
		)
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

		guard let collectionContents = repo[collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		var records: [Any] = []

		// TODO: Implement cursor and CID
		for (encodedRkey, _) in collectionContents {
			records.append(
				try getRecord(
					collection: collection,
					encodedRkey: .init(string: encodedRkey),
					cid: nil
				)
			)
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
	func putRecord(
		collection: String,
		rkey: String,
		encodedRecord: Data
	) throws {
		repo[collection, default: [:]][rkey] = encodedRecord
	}
}
