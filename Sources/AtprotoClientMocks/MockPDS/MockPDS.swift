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
import GermConvenienceHTTP

import struct HTTPTypes.HTTPResponse

public actor MockPDS {
	public nonisolated let serviceUrl: URL
	public nonisolated let authorizationServer: MockAS
	/// What `getRecord` answers a missing record with. Implementations
	/// disagree: the reference PDS sends 400, tranquil sends 404.
	public nonisolated let recordNotFoundStatus: HTTPResponse.Status

	public nonisolated var authorizationServerUrl: URL {
		authorizationServer.issuerUrl
	}

	private var repos: [Atproto.DID: MockRepo] = [:]

	/// A PDS that is its own authorization server, as a self-hosted PDS is: the
	/// issuer is `serviceUrl`, so the PDS also serves the authorization server
	/// metadata and endpoints.
	public init(recordNotFoundStatus: HTTPResponse.Status = .badRequest) throws {
		let serviceUrl = try Self.makeServiceUrl()
		self.init(
			serviceUrl: serviceUrl,
			authorizationServer: try MockAS(serviceUrl: serviceUrl),
			recordNotFoundStatus: recordNotFoundStatus
		)
	}

	/// A PDS behind a separate authorization server on its own host. Pass a
	/// shared `entryway` to put several PDSes behind one, as bsky.social does;
	/// by default the PDS gets its own.
	public static func withEntryway(
		_ entryway: MockAS? = nil,
		recordNotFoundStatus: HTTPResponse.Status = .badRequest
	) throws -> MockPDS {
		MockPDS(
			serviceUrl: try makeServiceUrl(),
			authorizationServer: try entryway ?? MockAS(),
			recordNotFoundStatus: recordNotFoundStatus
		)
	}

	private init(
		serviceUrl: URL,
		authorizationServer: MockAS,
		recordNotFoundStatus: HTTPResponse.Status
	) {
		self.serviceUrl = serviceUrl
		self.authorizationServer = authorizationServer
		self.recordNotFoundStatus = recordNotFoundStatus
	}

	//lowercase, so a PDS that is its own authorization server has an issuer
	//(an origin, which lowercases hosts) equal to its serviceUrl
	private static func makeServiceUrl() throws -> URL {
		try URL(string: "https://\(UUID().uuidString.lowercased()).example.com").unwrapped
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
		try await response(
			for: requestComponents.constructUrl(serviceUrl: serviceUrl),
			authedDid: authedDid
		)
	}

	/// Answers a request addressed to this PDS's host, for a router that already
	/// has the raw request. A PDS that is its own authorization server also
	/// answers the authorization server's endpoints.
	public func response(
		for request: BundledHTTPRequest,
		authedDid: Atproto.DID?
	) async throws -> HTTPDataResponse {
		if try authorizationServer.handles(request) {
			return try await authorizationServer.fetcher.data(for: request)
		}

		let requestUrl = try request.request.url.unwrapped

		let components = try URLComponents(
			url: requestUrl,
			resolvingAgainstBaseURL: false
		).unwrapped

		let path = requestUrl.path()
		let xrpcPrefix = "/xrpc/"

		if path.hasPrefix(xrpcPrefix) {
			return try await handleXrpc(
				xrpcNsid: .init(string: String(path.dropFirst(xrpcPrefix.count))),
				queryItems: components.queryItems,
				body: request.body,
				authedDid: authedDid
			)
		}
		if path == "/.well-known/oauth-protected-resource" {
			return .mock(json: try mockProtectedResourceMetadata)
		}
		//outside /xrpc/ there is no XRPC error envelope, just a plain 404
		return .init(data: Data(), response: .init(status: .notFound))

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
				authedDid: authedDid, bodyData: body.unwrapped
			)

		case Lexicon.Com.Atproto.Repo.PutRecordNSID.nsid:
			guard let authedDid else {
				return try .mock(error: "Unauthorized", status: 401)
			}

			return try await putRecord(
				authedDid: authedDid, bodyData: body.unwrapped
			)

		case Lexicon.Com.Atproto.Repo.DeleteRecordNSID.nsid:
			guard let authedDid else {
				return try .mock(error: "Unauthorized", status: 401)
			}

			return try await deleteRecord(
				authedDid: authedDid, bodyData: body.unwrapped
			)
		default:
			return try .mock(error: "InvalidRequest", status: 400)
		}
	}

	private var mockProtectedResourceMetadata: Data {
		get throws {
			try JSONSerialization.data(withJSONObject: [
				"resource": serviceUrl.absoluteString,
				"authorization_servers": [authorizationServerUrl.absoluteString],
				"scopes_supported": [],
				"bearer_methods_supported": ["header"],
				"resource_documentation": "https://atproto.com",
			])
		}
	}

	public func getRecord(
		queryItems: [URLQueryItem]?,
	) async throws -> HTTPDataResponse {
		let repoParam = try (queryItems?["repo"]).unwrapped
		let collection = try (queryItems?["collection"]).unwrapped
		let encodedRkey = try (queryItems?["rkey"]).unwrapped
		let cid = queryItems?["cid"]
		let typedCid: Atproto.CID? = try {
			guard let cid else {
				return nil
			}
			return try .init(string: cid)
		}()

		guard let repo = try repos[.init(string: repoParam)] else {
			return try .mock(error: "InvalidRequest", status: 400)
		}

		do {
			return try await repo.getRecordResponse(
				collection: .init(string: collection),
				encodedRkey: encodedRkey,
				cid: typedCid,
				notFoundStatus: recordNotFoundStatus
			)
			//GermConvenience 0.3.0 reports every failure as `.unsuccessful` and reads
			//the body through `bodyString`; `.unsuccessfulString` is no longer thrown
			//from that module. Match the type and use the accessors, so this keeps
			//converting whichever case a caller hands us. The body is the message —
			//the name stays a code the response parser can recognize.
		} catch let failure as HTTPResponseError {
			return try .mock(
				errorObject: .init(
					error: "InvalidRequest",
					message: failure.bodyString ?? "Mock Error"
				),
				status: .init(code: failure.statusCode)
			)
		}
	}

	private func listRecords(
		queryItems: [URLQueryItem]?
	) async throws -> HTTPDataResponse {
		let repoParam = try (queryItems?["repo"]).unwrapped
		let collection = try (queryItems?["collection"]).unwrapped
		let limit = queryItems?["limit"]
		let cursor = queryItems?["cursor"]
		let reverse = queryItems?["reverse"]

		guard let repo = try repos[.init(string: repoParam)] else {
			return try .mock(error: "InvalidRequest", status: 400)
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
			return try .mock(error: "InvalidRequest", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "InvalidRequest", status: 400)
		}

		//hacky, but type-erases the record type
		let input = try JSONSerialization.jsonObject(with: bodyData)
		let inputDict = try (input as? [String: Any]).unwrapped

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
			.data(withJSONObject: inputDict["record"].unwrapped)

		try await repo.createRecord(
			collection: protoSchema.collection,
			rkey: rkey,
			encodedRecord: encodedRecord
		)

		//unlike put, the caller did not choose the key, so the uri is the only
		//way it learns which record it just wrote
		return try .mock(
			encoding: Lexicon.Com.Atproto.Repo.PutRecordOutput(
				uri: repo.recordUri(
					collection: protoSchema.collection,
					rkey: rkey
				),
				cid: Atproto.CID.mock().rawValue,
				commit: try .mock(),
				validationStatus: .valid
			)
		)
	}

	private func putRecord(
		authedDid: Atproto.DID,
		bodyData: Data
	) async throws -> HTTPDataResponse {
		let protoSchema = try JSONDecoder().decode(ProtoSchema.self, from: bodyData)

		guard case .did(let did) = protoSchema.repo else {
			return try .mock(error: "InvalidRequest", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "InvalidRequest", status: 400)
		}

		//hacky, but type-erases the record type
		let input = try JSONSerialization.jsonObject(with: bodyData)
		let inputDict = try (input as? [String: Any]).unwrapped
		let inputRkey = try (inputDict["rkey"] as? String).unwrapped

		let encodedRecord =
			try JSONSerialization
			.data(withJSONObject: inputDict["record"].unwrapped)

		try await repo.putRecord(
			collection: protoSchema.collection,
			rkey: inputRkey,
			encodedRecord: encodedRecord
		)

		return try .mock(
			encoding: Lexicon.Com.Atproto.Repo.PutRecordOutput(
				uri: repo.recordUri(
					collection: protoSchema.collection,
					rkey: inputRkey
				),
				cid: Atproto.CID.mock().rawValue,
				commit: try .mock(),
				validationStatus: .valid
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
			return try .mock(error: "InvalidRequest", status: 400)
		}

		guard did == authedDid else {
			return try .mock(error: "Unauthorized", status: 401)
		}

		guard let repo = repos[authedDid] else {
			return try .mock(error: "InvalidRequest", status: 400)
		}

		let input = try JSONDecoder().decode(
			DeleteRecordSchema.self,
			from: bodyData
		)

		try await repo.deleteRecord(
			collection: input.collection,
			rkey: input.rkey
		)

		return try .mock(
			encoding: Lexicon.Com.Atproto.Repo.DeleteRecordOutput(
				commit: .init(
					cid: .mock(),
					rev: .mock()
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
		try await repos[did].unwrapped
			.getGraph()
	}

	public func getBskyProfile(did: Atproto.DID) async throws -> Lexicon.App.Bsky.Actor.Profile?
	{
		try await repos[did].unwrapped
			.getTypedRecord(
				collection: Lexicon.App.Bsky.Actor.Profile.Collection.nsid,
				encodedRkey: "self",
				cid: nil
			)

	}

	public func follow(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.unwrapped
			.follow(did: did)
	}

	public func block(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.unwrapped
			.block(did: did)
	}

	public func unfollow(did: Atproto.DID, from viewer: Atproto.DID) async throws {
		try await repos[viewer]
			.unwrapped
			.unfollow(did: did)
	}
}
