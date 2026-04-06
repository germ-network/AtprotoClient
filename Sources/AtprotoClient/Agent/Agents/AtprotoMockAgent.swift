//
//  AtprotoMockAgent.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/13/26.
//

import Foundation
import GermConvenience
import HTTPTypes

@testable import AtprotoTypes

public actor AtprotoMockAgent {
	public nonisolated let serviceUrl = URL(string: "https://mock-pds.germnetwork.com")!

	nonisolated public let did: Atproto.DID

	typealias EncodedRecordKey = String

	// Might want to check that the appropriate AtprotoRecord type is stored in a given NSID collection
	private var pds: [Atproto.NSID: [EncodedRecordKey: any AtprotoRecord]]

	let recordRegistry: [Atproto.NSID: any AtprotoRecord.Type]

	public init(
		did: Atproto.DID,
		recordRegistry: [Atproto.NSID: any AtprotoRecord.Type]
	) {
		self.did = did
		self.pds = [:]
		self.recordRegistry = recordRegistry
	}

	public func printPds() {
		print(pds)
	}
}

extension AtprotoMockAgent: XRPCCallable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
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
			return try getRecords(queryParameters: queryParameters)
		case Lexicon.Com.Atproto.Repo.listRecordsNSID:
			return try listRecords(queryParameters: queryParameters)
		//		case Lexicon.Com.Atproto.Sync.GetBlob.nsid:
		//			break
		case Lexicon.Com.Atproto.Repo.putRecordNSID:
			return try putRecord(bodyData: requestComponents.body.tryUnwrap)
		default:
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}
	}

	private func getRecords(
		queryParameters: [String: String]
	) throws -> HTTPDataResponse {
		let repo = try queryParameters["repo"].tryUnwrap
		let collection = try queryParameters["collection"].tryUnwrap
		let encodedRkey = try queryParameters["rkey"].tryUnwrap
		let cid = queryParameters["cid"]
		let typedCid: CID? = try {
			guard let cid else {
				return nil
			}
			return try .init(string: cid)
		}()

		guard let recordType: any AtprotoRecord.Type = self.recordRegistry[collection]
		else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		return try getRecordResponse(
			recordType,
			repo: .did(.init(string: repo)),
			encodedRkey: encodedRkey,
			cid: typedCid
		)
	}

	private func listRecords(
		queryParameters: [String: String]
	) throws -> HTTPDataResponse {
		let repo = try queryParameters["repo"].tryUnwrap
		let collection = try queryParameters["collection"].tryUnwrap
		let limit = queryParameters["limit"]
		let cursor = queryParameters["cursor"]
		let reverse = queryParameters["reverse"]

		guard let recordType: any AtprotoRecord.Type = self.recordRegistry[collection]
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
	}

	struct ProtoSchema: Decodable {
		let collection: Atproto.NSID
	}

	private func putRecord(
		bodyData: Data
	) throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard let recordType = recordRegistry[protoSchema.collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		//need the type to be known at compile type
		if recordType is Lexicon.App.Bsky.Actor.Profile.Type {
			let input = try JSONDecoder()
				.decode(
					Lexicon.Com.Atproto.Repo.PutRecord<
						Lexicon.App.Bsky.Actor.Profile
					>.Input.Schema.self,
					from: bodyData
				)

			guard input.repo.wireFormat == did.stringRepresentation else {
				throw HTTPResponseError.unsuccessfulString(400, "Incorrect repo")
			}

			pds[input.collection, default: [:]][input.rkey.stringRepresentation] =
				input.record

			let returnVal = Lexicon.Com.Atproto.Repo
				.PutRecordOutput(
					uri: "example.com",
					cid: "mock",
					validationStatus: .valid
				)
			return .init(
				data: try JSONEncoder().encode(returnVal),
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
		} else {

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

extension AtprotoMockAgent: PDSAgent {}

extension AtprotoMockAgent: XRPCAuthCallable {}

enum AtprotoMockAgentError: Error {
	case badParameters
}

// Get record
extension AtprotoMockAgent {
	func getRecord<R: AtprotoRecord>(
		_ type: R.Type,
		repo: AtIdentifier,
		encodedRkey: EncodedRecordKey,
		cid: CID?
	) throws -> Lexicon.Com.Atproto.Repo.GetRecord<R>.Output {
		guard repo.wireFormat == self.did.stringRepresentation else {
			throw HTTPResponseError.unsuccessfulString(400, "Incorrct repo")
		}

		guard let collectionContents = pds[R.nsid] else {
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
		repo: AtIdentifier,
		encodedRkey: EncodedRecordKey,
		cid: CID?
	) throws -> GermConvenience.HTTPDataResponse {
		let result = try getRecord(
			type,
			repo: repo,
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
extension AtprotoMockAgent {
	func listRecords<R: AtprotoRecord>(
		_ type: R.Type,
		repo: String,
		limit: Int?,
		cursor: String?,
		reverse: Bool?
	) throws -> Lexicon.Com.Atproto.Repo.ListRecords<R>.Output {
		guard repo == self.did.stringRepresentation else {
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
		for (encodedRkey, _) in collectionContents {
			records.append(
				try getRecord(
					type,
					repo: .did(.init(string: repo)),
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
		repo: String,
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
