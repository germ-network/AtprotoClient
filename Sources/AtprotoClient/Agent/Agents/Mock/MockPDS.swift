//
//  MockPDS.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/6/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

public actor MockPDS {
	public nonisolated let serviceUrl: URL

	private var repos: [Atproto.DID: MockRepo] = [:]
	var recordRegistry: [Atproto.NSID: any AtprotoRecord.Type] = [:]

	public init(recordRegistry: [any AtprotoRecord.Type] = []) throws {
		self.serviceUrl = try URL(
			string: "https://\(UUID().uuidString).example.com"
		).tryUnwrap
		
		self.recordRegistry = recordRegistry
			.reduce(into: [:]) { result, entry in
				result[entry.nsid] = entry
		}
	}

	public func register<R: AtprotoRecord>(type: R.Type) {
		recordRegistry[R.nsid] = R.self
	}

	public func host(did: Atproto.DID) throws -> AuthAgent {
		guard repos[did] == nil else {
			throw Errors.didAlreadyHostedHere
		}

		repos[did] = .init()
		return .init(did: did, pds: self)
	}

	//vend these out
	public struct PublicAgent {
		public let did: Atproto.DID
		let pds: MockPDS
	}

	public struct AuthAgent {
		public let did: Atproto.DID
		let pds: MockPDS
	}

	public func publicAgent(did: Atproto.DID) throws -> PublicAgent {
		try verifyHosting(did: did)
		return .init(did: did, pds: self)
	}

	public func authAgent(did: Atproto.DID) throws -> AuthAgent {
		try verifyHosting(did: did)
		return .init(did: did, pds: self)
	}

	private func verifyHosting(did: Atproto.DID) throws {
		guard repos[did] != nil else {
			throw Errors.didNotHostedHere
		}
	}

	public func response(
		_ requestComponents: XRPCRequestComponents,
		auth: Bool
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
		let queryParameters = try components.queryItems.tryUnwrap.asDictionary

		let xrpcNsid = pathComponents[2]
		switch xrpcNsid {
		case Lexicon.Com.Atproto.Repo.getRecordNSID:
			return try await getRecord(queryParameters: queryParameters)
		case Lexicon.Com.Atproto.Repo.listRecordsNSID:
			return try await listRecords(queryParameters: queryParameters)
		//		case Lexicon.Com.Atproto.Sync.GetBlob.nsid:
		//			break
		case Lexicon.Com.Atproto.Repo.putRecordNSID:
			guard auth else {
				throw HTTPResponseError.unsuccessfulString(401, "Unauthorized")
			}

			return try await putRecord(
				bodyData: requestComponents.body.tryUnwrap
			)
		default:
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		//here is where a directory of types would be handy
	}

	private func getRecord(
		queryParameters: [String: String]
	) async throws -> HTTPDataResponse {
		let repoParam = try queryParameters["repo"].tryUnwrap
		let collection = try queryParameters["collection"].tryUnwrap
		let encodedRkey = try queryParameters["rkey"].tryUnwrap
		let cid = queryParameters["cid"]
		let typedCid: CID? = try {
			guard let cid else {
				return nil
			}
			return try .init(string: cid)
		}()

		let repo = try repos[.init(string: repoParam)]
			.tryUnwrap(
				HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
			)

		guard let recordType: any AtprotoRecord.Type = self.recordRegistry[collection]
		else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		return try await repo.getRecordResponse(
			recordType,
			encodedRkey: encodedRkey,
			cid: typedCid
		)
	}

	private func listRecords(
		queryParameters: [String: String]
	) async throws -> HTTPDataResponse {
		let repoParam = try queryParameters["repo"].tryUnwrap
		let collection = try queryParameters["collection"].tryUnwrap
		let limit = queryParameters["limit"]
		let cursor = queryParameters["cursor"]
		let reverse = queryParameters["reverse"]

		guard let recordType: any AtprotoRecord.Type = self.recordRegistry[collection]
		else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		let repo = try repos[.init(string: repoParam)]
			.tryUnwrap(
				HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
			)

		return try await repo.listRecordsResponse(
			recordType,
			limit: limit,
			cursor: cursor,
			reverse: reverse,
		)
	}

	struct ProtoSchema: Decodable {
		let repo: AtIdentifier
		let collection: Atproto.NSID
	}

	private func putRecord(
		bodyData: Data
	) async throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard let recordType = recordRegistry[protoSchema.collection] else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		guard case .did(let did) = protoSchema.repo else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		let repo = try repos[did].tryUnwrap(
			HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		)

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

			await repo.putRecord(input: input)

			let returnVal = Lexicon.Com.Atproto.Repo
				.PutRecordResult(
					uri: "example.com",
					cid: "mock",
					validationStatus: "valid"
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

	enum Errors: Error {
		case didAlreadyHostedHere
		case didNotHostedHere
	}
}

extension MockPDS.PublicAgent: PDSAgent {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		try await pds.response(requestComponents, auth: false)
	}
}

extension MockPDS.AuthAgent: PDSAgent, XRPCAuthCallable {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		try await pds.response(requestComponents, auth: true)
	}
}

extension [URLQueryItem] {
	var asDictionary: [String: String] {
		reduce(into: [:]) { result, queryItem in
			result[queryItem.name] = queryItem.value
		}
	}
}
