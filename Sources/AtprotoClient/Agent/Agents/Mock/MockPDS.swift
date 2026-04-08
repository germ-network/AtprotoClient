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

	public init() throws {
		self.serviceUrl = try URL(
			string: "https://\(UUID().uuidString).example.com"
		).tryUnwrap
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

		let components = try URLComponents(
			url: requestUrl,
			resolvingAgainstBaseURL: false
		).tryUnwrap
		let queryParameters = try components.queryItems.tryUnwrap.asDictionary

		let pathComponents = requestUrl.pathComponents

		switch pathComponents[1] {
		case "xrpc":
			return try await handleXrpc(
				xrpcNsid: pathComponents[2],
				queryParameters: queryParameters,
				body: requestComponents.body,
				auth: auth
			)
		case ".well-known":
			return try await handleWellKnown(path: .init(pathComponents[2...]))
		default:
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		//here is where a directory of types would be handy
	}

	private func handleXrpc(
		xrpcNsid: Atproto.NSID,
		queryParameters: [String: String],
		body: Data?,
		auth: Bool
	) async throws -> HTTPDataResponse {
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
				bodyData: body.tryUnwrap
			)
		default:
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}
	}

	private func handleWellKnown(path: [String]) async throws -> HTTPDataResponse {
		guard let component = path.first, path.count == 1 else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
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
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
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
		{"issuer":"https://bsky.social","request_parameter_supported":true,"request_uri_parameter_supported":true,"require_request_uri_registration":true,"scopes_supported":["atproto","transition:email","transition:generic","transition:chat.bsky"],"subject_types_supported":["public"],"response_types_supported":["code"],"response_modes_supported":["query","fragment","form_post"],"grant_types_supported":["authorization_code","refresh_token"],"code_challenge_methods_supported":["S256"],"ui_locales_supported":["en-US"],"display_values_supported":["page","popup","touch"],"request_object_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512","none"],"authorization_response_iss_parameter_supported":true,"request_object_encryption_alg_values_supported":[],"request_object_encryption_enc_values_supported":[],"jwks_uri":"https://bsky.social/oauth/jwks","authorization_endpoint":"https://bsky.social/oauth/authorize","token_endpoint":"https://bsky.social/oauth/token","token_endpoint_auth_methods_supported":["none","private_key_jwt"],"token_endpoint_auth_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512"],"revocation_endpoint":"https://bsky.social/oauth/revoke","pushed_authorization_request_endpoint":"https://bsky.social/oauth/par","require_pushed_authorization_requests":true,"dpop_signing_alg_values_supported":["RS256","RS384","RS512","PS256","PS384","PS512","ES256","ES256K","ES384","ES512"],"client_id_metadata_document_supported":true,"prompt_values_supported":["none","login","consent","select_account","create"]}
		"""

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

		do {
			return try await repo.getRecordResponse(
				collection: collection,
				encodedRkey: encodedRkey,
				cid: typedCid
			)
		} catch HTTPResponseError.unsuccessfulString(let code, let error) {
			return .init(
				data: try JSONEncoder().encode(
					Lexicon.XRPCError(error: error, message: error)),
				response: .init(status: .init(code: code))
			)
		}
	}

	private func listRecords(
		queryParameters: [String: String]
	) async throws -> HTTPDataResponse {
		let repoParam = try queryParameters["repo"].tryUnwrap
		let collection = try queryParameters["collection"].tryUnwrap
		let limit = queryParameters["limit"]
		let cursor = queryParameters["cursor"]
		let reverse = queryParameters["reverse"]

		let repo = try repos[.init(string: repoParam)]
			.tryUnwrap(
				HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
			)

		return try await repo.listRecordsResponse(
			collection: collection,
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

		guard case .did(let did) = protoSchema.repo else {
			throw HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		}

		let repo = try repos[did].tryUnwrap(
			HTTPResponseError.unsuccessfulString(400, "InvalidRequest")
		)

		//hacky, but type-erases the record type
		let input = try JSONSerialization.jsonObject(with: bodyData)
		let inputDict = try (input as? [String: Any]).tryUnwrap
		let inputRepo = try (inputDict["repo"] as? String).tryUnwrap
		let inputRkey = try (inputDict["rkey"] as? String).tryUnwrap
		let inputCollection = try (inputDict["collection"] as? String).tryUnwrap

		let encodedRecord =
			try JSONSerialization
			.data(withJSONObject: inputDict["record"].tryUnwrap)

		guard inputRepo == did.stringRepresentation else {
			throw HTTPResponseError.unsuccessfulString(400, "Incorrect repo")
		}

		try await repo.putRecord(
			collection: inputCollection,
			rkey: inputRkey,
			encodedRecord: encodedRecord
		)

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
