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
	private var repo: [Atproto.NSID: [EncodedRecordKey: any AtprotoRecord]] = [:]

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
	func getRecord<R: AtprotoRecord>(
		_ type: R.Type,
		encodedRkey: EncodedRecordKey,
		cid: CID?
	) throws -> Lexicon.Com.Atproto.Repo.GetRecord<R>.Output {
		guard let collectionContents = repo[R.nsid] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let record = collectionContents[encodedRkey] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		// TODO: Mock CID
		return Lexicon.Com.Atproto.Repo.GetRecord<R>.Output(
			uri: UUID().uuidString,
			cid: cid?.string ?? CID.mock().string,
			value: record as! R
		)
	}

	func getRecordResponse<R: AtprotoRecord>(
		_ type: R.Type,
		encodedRkey: EncodedRecordKey,
		cid: CID?
	) throws -> GermConvenience.HTTPDataResponse {
		let result = try getRecord(
			type,
			encodedRkey: encodedRkey,
			cid: cid
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
							value: HTTPContentType.json.rawValue)
					]
				)
			)
		)
	}
}

// List records
extension MockRepo {
	func listRecords<R: AtprotoRecord>(
		_ type: R.Type,
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) throws -> Lexicon.Com.Atproto.Repo.ListRecords<R>.Output {
		if let limit {
			guard limit >= 1, limit <= 100 else {
				throw AtprotoMockAgentError.badParameters
			}
		}

		guard let collectionContents = repo[R.nsid] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		var records: [Lexicon.Com.Atproto.Repo.GetRecord<R>.Output] = []

		// TODO: Implement cursor and CID
		for (encodedRkey, _) in collectionContents {
			records.append(
				try getRecord(
					type,
					encodedRkey: .init(string: encodedRkey),
					cid: nil
				)
			)
		}

		return Lexicon.Com.Atproto.Repo.ListRecords<R>.Output(
			cursor: nil,
			records: records as! [Lexicon.Com.Atproto.Repo.ListRecords<R>.Record]
		)
	}

	func listRecordsResponse<R: AtprotoRecord>(
		_ type: R.Type,
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
			type,
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
	func putRecord<R: AtprotoRecord>(
		input: Lexicon.Com.Atproto.Repo.PutRecord<R>.Input.Schema
	) {
		repo[input.collection, default: [:]][input.rkey.stringRepresentation] =
			input.record
	}
}
