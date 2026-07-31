//
//  MockPDS.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/6/26.
//

import AtprotoClient
import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import GermConvenience

public actor MockPDS {
	public nonisolated let serviceUrl: URL

	private var repos: [Atproto.DID: MockRepo] = [:]

	public init() throws {
		self.serviceUrl = try URL(
			string: "https://\(UUID().uuidString).example.com"
		).tryUnwrap
	}

	public func host(
		did: Atproto.DID,
		bskyProfile: Lexicon.App.Bsky.Actor.Profile? = nil
	) throws -> AuthAgent {
		guard repos[did] == nil else {
			throw Errors.didAlreadyHostedHere
		}

		repos[did] = try .init(did: did, bskyProfile: bskyProfile)

		return .init(did: did, pds: self)
	}

	//vend these out
	public struct PublicAgent {
		public let did: Atproto.DID
		let pds: MockPDS
	}

	public struct AuthAgent {
		public let did: Atproto.DID
		package let pds: MockPDS
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
		authedDid: Atproto.DID?
	) async throws -> HTTPDataResponse {
		let request = try requestComponents.constructUrl(serviceUrl: serviceUrl)
		let requestUrl = try request.request.url.tryUnwrap

		let components = try URLComponents(
			url: requestUrl,
			resolvingAgainstBaseURL: false
		).tryUnwrap

		let pathComponents = requestUrl.pathComponents

		switch pathComponents[1] {
		case "xrpc":
			return try await handleXrpc(
				xrpcNsid: .init(string: pathComponents[2]),
				queryItems: components.queryItems,
				body: requestComponents.body,
				authedDid: authedDid
			)
		case ".well-known":
			return try await handleWellKnown(path: .init(pathComponents[2...]))
		default:
			return try .mock(error: "Invalid Request", status: 400)
		}

		//here is where a directory of types would be handy
	}

	private func handleXrpc(
		xrpcNsid: Atproto.NSID,
		queryItems: [URLQueryItem]?,
		body: Data?,
		authedDid: Atproto.DID?
	) async throws -> HTTPDataResponse {
		switch xrpcNsid {
		case Lexicon.Com.Atproto.Repo.GetRecordNSID.nsid:
			return try await getRecord(queryItems: queryItems)
		case Lexicon.Com.Atproto.Repo.ListRecordsNSID.nsid:
			return try await listRecords(queryItems: queryItems)
		//		case Lexicon.Com.Atproto.Sync.GetBlob.nsid:
		//			break
		case Lexicon.Com.Atproto.Repo.CreateRecordNSID.nsid:
			guard let authedDid else {
				return try .mock(error: "Unauthorized", status: 401)
			}

			return try await createRecord(
				authedDid: authedDid, bodyData: body.tryUnwrap
			)

		case Lexicon.Com.Atproto.Repo.PutRecordNSID.nsid:
			guard let authedDid else {
				return try .mock(error: "Unauthorized", status: 401)
			}

			return try await putRecord(
				authedDid: authedDid, bodyData: body.tryUnwrap
			)

		case Lexicon.Com.Atproto.Repo.DeleteRecordNSID.nsid:
			guard let authedDid else {
				return try .mock(error: "Unauthorized", status: 401)
			}

			return try await deleteRecord(
				authedDid: authedDid, bodyData: body.tryUnwrap
			)
		default:
			return try .mock(error: "Invalid Request", status: 400)
		}
	}

	private func handleWellKnown(path: [String]) async throws -> HTTPDataResponse {
		guard let component = path.first, path.count == 1 else {
			return try .mock(error: "Invalid Request", status: 400)
		}
		switch component {
		case "oauth-protected-resource":
			return .init(
				data: try mockProtectedResourceMetadata,
				response: .init(status: .ok)
			)
		case "oauth-authorization-server":
			return .init(
				data: Self.mockAuthMetadata.utf8Data,
				response: .init(status: .ok)
			)
		default:
			return try .mock(error: "Invalid Request", status: 400)
		}
	}

	private var mockProtectedResourceMetadata: Data {
		get throws {
			try JSONSerialization.data(withJSONObject: [
				"resource": serviceUrl.absoluteString,
				"authorization_servers": [serviceUrl.absoluteString],
				"scopes_supported": [],
				"bearer_methods_supported": ["header"],
				"resource_documentation": "https://atproto.com",
			])
		}
	}

	private static let mockAuthMetadata =
		"""
		{"issuer":"https://example.com","request_parameter_supported":true,"request_uri_parameter_supported":true,"require_request_uri_registration":true,"scopes_supported":["atproto","transition:email","transition:generic","transition:chat.bsky"],"subject_types_supported":["public"],"response_types_supported":["code"],"response_modes_supported":["query","fragment","form_post"],"grant_types_supported":["authorization_code","refresh_token"],"code_challenge_methods_supported":["S256"],"ui_locales_supported":["en-US"],"display_values_supported":["page","popup","touch"],"request_object_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512","none"],"authorization_response_iss_parameter_supported":true,"request_object_encryption_alg_values_supported":[],"request_object_encryption_enc_values_supported":[],"jwks_uri":"https://example.com/oauth/jwks","authorization_endpoint":"https://example.com/oauth/authorize","token_endpoint":"https://example.com/oauth/token","token_endpoint_auth_methods_supported":["none","private_key_jwt"],"token_endpoint_auth_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512"],"revocation_endpoint":"https://example.com/oauth/revoke","pushed_authorization_request_endpoint":"https://example.com/oauth/par","require_pushed_authorization_requests":true,"dpop_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512"],"client_id_metadata_document_supported":true,"prompt_values_supported":["none","login","consent","select_account","create"]}
		"""

	public func getRecord(
		queryItems: [URLQueryItem]?,
	) async throws -> HTTPDataResponse {
		let repoParam = try (queryItems?["repo"]).tryUnwrap
		let collection = try (queryItems?["collection"]).tryUnwrap
		let encodedRkey = try (queryItems?["rkey"]).tryUnwrap
		let cid = queryItems?["cid"]
		let typedCid: Atproto.CID? = try {
			guard let cid else {
				return nil
			}
			return try .init(string: cid)
		}()

		guard let repo = try repos[.init(string: repoParam)] else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		do {
			return try await repo.getRecordResponse(
				collection: .init(string: collection),
				encodedRkey: encodedRkey,
				cid: typedCid
			)
		} catch HTTPResponseError.unsuccessfulString(let code, let error) {
			return .init(
				data: try JSONEncoder().encode(
					Atproto.XRPC.ErrorResponse(error: error, message: error)),
				response: .init(status: .init(code: code))
			)
		}
	}

	private func listRecords(
		queryItems: [URLQueryItem]?
	) async throws -> HTTPDataResponse {
		let repoParam = try (queryItems?["repo"]).tryUnwrap
		let collection = try (queryItems?["collection"]).tryUnwrap
		let limit = queryItems?["limit"]
		let cursor = queryItems?["cursor"]
		let reverse = queryItems?["reverse"]

		guard let repo = try repos[.init(string: repoParam)] else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		return try await repo.listRecordsResponse(
			collection: .init(string: collection),
			limit: limit,
			cursor: cursor,
			reverse: reverse,
		)
	}

	struct ProtoSchema: Decodable {
		let repo: LexiconString.AtIdentifier
		let collection: Atproto.NSID
	}

	//Same guards and body handling as `putRecord`; the difference is the record
	//key. Create mints one — a TID, since that is what the record keys the app
	//then reads back out of `uri` have to parse as — where put takes one from the
	//input.
	private func createRecord(
		authedDid: Atproto.DID,
		bodyData: Data
	) async throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard case .did(let did) = protoSchema.repo else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		//hacky, but type-erases the record type
		let input = try JSONSerialization.jsonObject(with: bodyData)
		let inputDict = try (input as? [String: Any]).tryUnwrap

		//The lexicon's optional rkey is deliberately NOT modeled. Honoring it
		//without also modeling the already-exists failure would just be putRecord
		//wearing create's name, and minting a different key anyway would strand a
		//caller that asked for a specific one. Refuse it, loudly: a test that wants
		//to choose the key wants `putRecord(_:input:)`.
		guard inputDict["rkey"] as? String == nil else {
			return try .mock(
				errorObject: .init(
					error: "InvalidRequest",
					message:
						"MockPDS mints record keys; use putRecord to choose one"
				),
				status: .badRequest
			)
		}
		let rkey = Atproto.TID.mock().rawValue

		let encodedRecord =
			try JSONSerialization
			.data(withJSONObject: inputDict["record"].tryUnwrap)

		try await repo.createRecord(
			collection: protoSchema.collection,
			rkey: rkey,
			encodedRecord: encodedRecord
		)

		//unlike put, the caller did not choose the key, so the uri is the only
		//way it learns which record it just wrote
		let returnVal = Lexicon.Com.Atproto.Repo
			.PutRecordOutput(
				uri: repo.recordUri(
					collection: protoSchema.collection,
					rkey: rkey
				),
				cid: "mock",
				commit: try .mock(),
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
	}

	private func putRecord(
		authedDid: Atproto.DID,
		bodyData: Data
	) async throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard case .did(let did) = protoSchema.repo else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		//hacky, but type-erases the record type
		let input = try JSONSerialization.jsonObject(with: bodyData)
		let inputDict = try (input as? [String: Any]).tryUnwrap
		let inputRkey = try (inputDict["rkey"] as? String).tryUnwrap

		let encodedRecord =
			try JSONSerialization
			.data(withJSONObject: inputDict["record"].tryUnwrap)

		try await repo.putRecord(
			collection: protoSchema.collection,
			rkey: inputRkey,
			encodedRecord: encodedRecord
		)

		let returnVal = Lexicon.Com.Atproto.Repo
			.PutRecordOutput(
				uri: "example.com",
				cid: "mock",
				commit: try .mock(),
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
	}

	struct DeleteRecordSchema: Decodable {
		let repo: LexiconString.AtIdentifier
		let collection: Atproto.NSID
		let rkey: String
		let swapRecord: Atproto.CID?
		let swapCommit: Atproto.CID?
	}

	private func deleteRecord(
		authedDid: Atproto.DID,
		bodyData: Data
	) async throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard case .did(let did) = protoSchema.repo else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "Invalid Request", status: 400)
		}

		let input = try JSONDecoder().decode(
			DeleteRecordSchema.self,
			from: bodyData
		)

		try await repo.deleteRecord(
			collection: input.collection,
			rkey: input.rkey
		)

		let returnVal = Lexicon.Com.Atproto.Repo
			.DeleteRecordOutput(
				commit: .init(
					cid: .mock(),
					rev: .mock()
				)
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
	}

	enum Errors: Error {
		case missingAuthHeader
		case missingDPoPHeader
		case didAlreadyHostedHere
		case didNotHostedHere
	}
}

extension MockPDS.PublicAgent: Atproto.PDSAgent {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		try await pds.response(requestComponents, authedDid: nil)
	}
}

extension MockPDS.AuthAgent: Atproto.AuthPDSAgent {
	public func response(
		_ requestComponents: XRPCRequestComponents
	) async throws -> HTTPDataResponse {
		try await pds.response(requestComponents, authedDid: did)
	}
}

extension [URLQueryItem] {
	public subscript(name: String) -> String? {
		first(where: { $0.name == name })?
			.value
	}
}

extension MockPDS {
	public func getGraph(did: Atproto.DID) async throws -> (
		[Lexicon.App.Bsky.Graph.Follow], [Lexicon.App.Bsky.Graph.Block]
	) {
		try await repos[did].tryUnwrap
			.getGraph()
	}

	public func getBskyProfile(did: Atproto.DID) async throws -> Lexicon.App.Bsky.Actor.Profile?
	{
		try await repos[did].tryUnwrap
			.getTypedRecord(
				collection: Lexicon.App.Bsky.Actor.Profile.Collection.nsid,
				encodedRkey: "self",
				cid: nil
			)

	}

	public func follow(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.tryUnwrap
			.follow(did: did)
	}

	public func block(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.tryUnwrap
			.block(did: did)
	}

	public func unfollow(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.tryUnwrap
			.unfollow(did: did)
	}
}
