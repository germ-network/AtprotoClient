//
//  AtprotoAgent+Mock.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/13/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

public actor AtprotoMockAgent {
	public nonisolated let serviceUrl = URL(string: "https://mock-pds.germnetwork.com")!

	nonisolated let repo: Atproto.DID

	// Might want to check that the appropriate AtprotoRecord type is stored in a given NSID collection
	private var pds: [Atproto.NSID: [Atproto.RecordKey: AtprotoRecord]]

	let recordRegistry: [Atproto.NSID: AtprotoRecord.Type]

	public init(
		repo: Atproto.DID,
		recordRegistry: [Atproto.NSID: AtprotoRecord.Type]
	) {
		self.repo = repo
		self.pds = [:]
		self.recordRegistry = recordRegistry
	}

	public func putRecord<R: AtprotoRecord>(
		record: R,
		repo: String,
		rkey: String,
	) throws {
		guard repo == self.repo.stringRepresentation else {
			throw HTTPResponseError.unsuccessfulString(400, "Incorrct repo")
		}

		pds[R.nsid, default: [:]][rkey] = record
	}

	public func printPds() {
		print(pds)
	}
}

extension AtprotoMockAgent: AtprotoAgent {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> GermConvenience.HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)
		let requestUrl = try request.request.url.tryUnwrap
		let pathComponents = requestUrl.pathComponents

		// pathComponents[0] is "/"
		guard pathComponents[1] == "xrpc" else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		let components = try URLComponents(
			url: requestUrl,
			resolvingAgainstBaseURL: false
		).tryUnwrap
		let queryParameters = getQueryDictionary(
			for: try components.queryItems.tryUnwrap
		)

		switch pathComponents[pathComponents.endIndex - 1] {
		case Lexicon.Com.Atproto.Repo.getRecordNSID:
			let repo = try queryParameters["repo"].tryUnwrap
			let collection = try queryParameters["collection"].tryUnwrap
			let rkey = try queryParameters["rkey"].tryUnwrap
			let cid = queryParameters["cid"]

			guard let recordType: AtprotoRecord.Type = self.recordRegistry[collection]
			else {
				throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
			}

			return try getRecordResponse(
				recordType,
				repo: repo,
				rkey: rkey,
				cid: cid,
			)
		case Lexicon.Com.Atproto.Repo.listRecordsNSID:
			let repo = try queryParameters["repo"].tryUnwrap
			let collection = try queryParameters["collection"].tryUnwrap
			let limit = queryParameters["limit"]
			let cursor = queryParameters["cursor"]
			let reverse = queryParameters["reverse"]

			guard let recordType: AtprotoRecord.Type = self.recordRegistry[collection]
			else {
				throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
			}

			return try listRecordsResponse(
				recordType,
				repo: repo,
				limit: limit,
				cursor: cursor,
				reverse: reverse,
			)
		//		case Lexicon.Com.Atproto.Sync.GetBlob.nsid:
		//			break
		default:
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}
	}

	private func getQueryDictionary(for queryItems: [URLQueryItem]) -> [String: String] {
		var queryDictionary: [String: String] = [:]
		for param in queryItems {
			queryDictionary[param.name] = param.value
		}
		return queryDictionary
	}
}

enum AtprotoMockAgentError: Error {
	case badParameters
}

// Get record
extension AtprotoMockAgent {
	func getRecord<R: AtprotoRecord>(
		_ type: R.Type,
		repo: String,
		rkey: String,
		cid: String?
	) throws -> Lexicon.Com.Atproto.Repo.GetRecord<R>.Output {
		guard repo == self.repo.stringRepresentation else {
			throw HTTPResponseError.unsuccessfulString(400, "Incorrct repo")
		}

		guard let collectionContents = pds[R.nsid] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let record = collectionContents[rkey] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		// TODO: Mock CID
		return Lexicon.Com.Atproto.Repo.GetRecord<R>.Output(
			uri: UUID().uuidString,
			cid: cid ?? CID.mock().string,
			value: record as! R
		)
	}

	func getRecordResponse<R: AtprotoRecord>(
		_ type: R.Type,
		repo: String,
		rkey: String,
		cid: String?
	) throws -> GermConvenience.HTTPDataResponse {
		let result = try getRecord(
			type,
			repo: repo,
			rkey: rkey,
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
extension AtprotoMockAgent {
	func listRecords<R: AtprotoRecord>(
		_ type: R.Type,
		repo: String,
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) throws -> Lexicon.Com.Atproto.Repo.ListRecords<R>.Output {
		guard repo == self.repo.stringRepresentation else {
			throw HTTPResponseError.unsuccessfulString(400, "Incorrct repo")
		}

		if let limit {
			guard limit >= 1, limit <= 100 else {
				throw AtprotoMockAgentError.badParameters
			}
		}

		guard let collectionContents = pds[R.nsid] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		var records: [Lexicon.Com.Atproto.Repo.GetRecord<R>.Output] = []

		// TODO: Implement cursor and CID
		for (rkey, _) in collectionContents {
			records.append(
				try getRecord(
					type,
					repo: repo,
					rkey: rkey,
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
		repo: String,
		limit: String?,
		cursor: String?,
		reverse: String?
	) throws -> GermConvenience.HTTPDataResponse {
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
			repo: repo,
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
