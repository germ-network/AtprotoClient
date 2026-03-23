//
//  AtprotoAgent+Mock.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/13/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public actor AtprotoMockAgentImpl {
	public nonisolated let repo: Atproto.DID
	public nonisolated let resolver: AtprotoResolver

	// Might want to check that the appropriate AtprotoRecord type is stored in a given NSID collection
	private var pds: [Atproto.DID: [Atproto.NSID: [Atproto.RecordKey: AtprotoRecord]]]
	private var pdsURL = URL(string: "https://mock-pds.germnetwork.com")!

	public init(for did: Atproto.DID) {
		self.pds = [:]
		self.repo = did
		self.resolver = AtprotoMockResolver()
	}

	public func putRecord<R: AtprotoRecord>(
		record: R,
		repo: String,
		rkey: String,
	) throws {
		let did = try Atproto.DID(string: repo)
		pds[did, default: [:]][R.nsid, default: [:]][rkey] = record
	}

	public func printPds() {
		print(pds)
	}
}

extension AtprotoMockAgentImpl: AtprotoAgent {
	public nonisolated var allowsAuthedCalls: Bool { true }

	public func authResponse(_ request: AtprotoAgentRequest) async throws
		-> GermConvenience.HTTPDataResponse
	{
		throw AtprotoMockAgentError.notImplemented
	}

	public func response(_ request: AtprotoAgentRequest) async throws
		-> GermConvenience.HTTPDataResponse
	{
		let pathComponents = request.relativePath.components(separatedBy: "/")
		// pathComponents[0] is "/"
		guard pathComponents[1] == "xrpc" else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		let queryParameters = getQueryDictionary(for: request.queryItems)

		switch pathComponents[pathComponents.endIndex - 1] {
		case Lexicon.Com.Atproto.Repo.getRecordNSID:
			let repo = try queryParameters["repo"].tryUnwrap
			let collection = try queryParameters["collection"].tryUnwrap
			let rkey = try queryParameters["rkey"].tryUnwrap
			let cid = queryParameters["cid"]
			return try getRecordResponse(
				repo: repo,
				collection: collection,
				rkey: rkey,
				cid: cid,
			)
		case Lexicon.Com.Atproto.Repo.listRecordsNSID:
			let repo = try queryParameters["repo"].tryUnwrap
			let collection = try queryParameters["collection"].tryUnwrap
			let limit = queryParameters["limit"]
			let cursor = queryParameters["cursor"]
			let reverse = queryParameters["reverse"]
			return try listRecordsResponse(
				repo: repo,
				collection: collection,
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
	case notImplemented
	case unexpectedRecordType
}

// Get record
extension AtprotoMockAgentImpl {
	public struct MockGetRecordResult: Sendable, Codable {
		public let uri: String
		public let cid: String
		public let value: Data

		init(uri: String, cid: String, value: AtprotoRecord) throws {
			self.uri = uri
			self.cid = cid
			self.value = try JSONEncoder().encode(value)
		}
	}

	func getRecord(
		repo: String,
		collection: String,
		rkey: String,
		cid: String?
	) throws -> MockGetRecordResult {
		let did = try Atproto.DID(string: repo)
		guard let repoContents = pds[did] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let collectionContents = repoContents[collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let record = collectionContents[rkey] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		// TODO: Mock CID
		return try MockGetRecordResult(
			uri: UUID().uuidString,
			cid: cid ?? CID.mock().string,
			value: record
		)
	}

	func getRecordResponse(
		repo: String,
		collection: String,
		rkey: String,
		cid: String?
	) throws -> GermConvenience.HTTPDataResponse {
		let result = try getRecord(repo: repo, collection: collection, rkey: rkey, cid: cid)
		let data = try JSONEncoder().encode(result)
		return .init(
			data: data,
			response: try HTTPURLResponse(
				url: pdsURL,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["Content-Type": "application/json"]
			).tryUnwrap
		)
	}
}

// List records
extension AtprotoMockAgentImpl {
	public struct MockListRecordsResult: Sendable, Codable {
		public let cursor: String?
		public let records: [MockGetRecordResult]
	}

	func listRecords(
		repo: String,
		collection: String,
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) throws -> MockListRecordsResult {
		if let limit {
			guard limit >= 1, limit <= 100 else {
				throw AtprotoMockAgentError.badParameters
			}
		}

		let did = try Atproto.DID(string: repo)
		guard let repoContents = pds[did] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}
		guard let collectionContents = repoContents[collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "RecordNotFound")
		}

		var records: [MockGetRecordResult] = []

		// TODO: Implement cursor and CID
		for (rkey, _) in collectionContents {
			records.append(
				try getRecord(
					repo: repo,
					collection: collection,
					rkey: rkey,
					cid: nil
				)
			)
		}

		return MockListRecordsResult(
			cursor: nil,
			records: records
		)
	}

	func listRecordsResponse(
		repo: String,
		collection: String,
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
			repo: repo,
			collection: collection,
			limit: limitInt,
			cursor: cursor,
			reverse: reverseBool
		)
		let data = try JSONEncoder().encode(result)
		return .init(
			data: data,
			response: try HTTPURLResponse(
				url: pdsURL,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["Content-Type": "application/json"]
			).tryUnwrap
		)
	}
}
