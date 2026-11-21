//
//  MockASTests.swift
//  AtprotoClientTests
//
//  `MockAS` against the two ways a PDS meets its authorization server: as its
//  own (the default, as a self-hosted PDS is) or behind a separate entryway.
//  OAuth discovery needs the `issuer` to exactly match the server listed in
//  the protected resource metadata, so most of what follows checks the two
//  documents agree, and that each is served from the right host.
//

import AtprotoClient
import AtprotoClientMocks
import Foundation
import GermConvenience
import GermConvenienceHTTP
import GermConvenienceMocks
import HTTPTypes
import Testing

struct MockASTests {
	@Test func colocatedPDSIsItsOwnAuthorizationServer() async throws {
		let pds = try MockPDS()

		#expect(pds.authorizationServerUrl == pds.serviceUrl)

		let resource = try await Self.json(pds, "/.well-known/oauth-protected-resource")
		#expect(resource["resource"] as? String == pds.serviceUrl.absoluteString)
		#expect(
			resource["authorization_servers"] as? [String]
				== [pds.serviceUrl.absoluteString]
		)

		let metadata = try await Self.json(pds, "/.well-known/oauth-authorization-server")
		#expect(metadata["issuer"] as? String == pds.serviceUrl.absoluteString)
	}

	@Test func entrywayPDSPointsAtASeparateHost() async throws {
		let pds = try MockPDS.withEntryway()
		let issuer = pds.authorizationServerUrl

		#expect(issuer.host() != pds.serviceUrl.host())

		let resource = try await Self.json(pds, "/.well-known/oauth-protected-resource")
		#expect(resource["authorization_servers"] as? [String] == [issuer.absoluteString])

		//the PDS host is not the authorization server, so it does not answer for it
		let fromPDS = try await pds.response(
			Self.get("/.well-known/oauth-authorization-server"),
			authedDid: nil
		)
		#expect(fromPDS.response.status == .notFound)

		let fromAS = try await pds.authorizationServer.fetcher.data(
			for: .init(url: pds.authorizationServer.url(for: .metadata))
		)
		let metadata = try Self.object(fromAS.data)
		#expect(metadata["issuer"] as? String == issuer.absoluteString)
	}

	@Test func entrywayCanBeSharedAcrossPDSes() throws {
		let entryway = try MockAS()
		let first = try MockPDS.withEntryway(entryway)
		let second = try MockPDS.withEntryway(entryway)

		#expect(first.serviceUrl != second.serviceUrl)
		#expect(first.authorizationServerUrl == entryway.issuerUrl)
		#expect(second.authorizationServerUrl == entryway.issuerUrl)
	}

	@Test func metadataEndpointsAreAllUnderTheIssuer() async throws {
		let authorizationServer = try MockAS()
		let metadata = try Self.object(
			try await Self.metadataBody(authorizationServer)
		)

		let advertised: [String: MockAS.Endpoint] = [
			"jwks_uri": .jwks,
			"authorization_endpoint": .authorization,
			"token_endpoint": .token,
			"revocation_endpoint": .revocation,
			"pushed_authorization_request_endpoint": .pushedAuthorizationRequest,
		]
		for (key, endpoint) in advertised {
			#expect(
				metadata[key] as? String
					== authorizationServer.url(for: endpoint).absoluteString,
				"\(key)"
			)
		}
	}

	@Test func aTestCanOverrideTheDefaultMetadata() async throws {
		let authorizationServer = try MockAS()
		let metadataUrl = authorizationServer.url(for: .metadata)
		let override = Data(#"{"issuer":"https://override.example.com"}"#.utf8)

		await authorizationServer.fetcher.on(metadataUrl, method: .get)
			.always(.success(.ok(override)))

		let response = try await authorizationServer.fetcher.data(
			for: .init(url: metadataUrl)
		)
		#expect(response.data == override)
	}

	//a router hands the PDS the raw request, so what reaches the authorization
	//server is exactly what the client sent
	@Test func pushedAuthorizationRequestReachesAColocatedFetcher() async throws {
		let pds = try MockPDS()
		let parUrl = pds.authorizationServer.url(for: .pushedAuthorizationRequest)
		await pds.authorizationServer.fetcher.on(parUrl, method: .post)
			.enqueue(.success(.ok(#"{"request_uri":"urn:x"}"#)))

		let dpop = try HTTPField.Name("DPoP").unwrapped
		let body = Data("client_id=https%3A%2F%2Fclient.example.com&state=abc".utf8)
		_ = try await pds.response(
			for: .init(
				method: .post,
				url: parUrl,
				headerFields: [
					.contentType: "application/x-www-form-urlencoded",
					dpop: "proof",
				],
				body: body
			),
			authedDid: nil
		)

		let pushed = try await pds.authorizationServer.fetcher
			.firstRequest(for: parUrl, method: .post)
		#expect(pushed.request.method == .post)
		#expect(pushed.request.headerFields[dpop] == "proof")
		#expect(pushed.body == body)
	}

	@Test func handlesOnlyItsOwnEndpoints() throws {
		let authorizationServer = try MockAS()
		let issuer = authorizationServer.issuerUrl

		#expect(
			try authorizationServer.handles(
				.init(url: authorizationServer.url(for: .token))
			)
		)
		#expect(
			try !authorizationServer.handles(.init(url: issuer.appending(path: "xrpc/x")))
		)
		#expect(
			try !authorizationServer.handles(
				.init(url: try #require(URL(string: "https://other.example.com/oauth/par")))
			)
		)
	}
}

extension MockASTests {
	static func get(_ path: String) -> XRPCRequestComponents {
		.init(relativePath: path, queryItems: [], headers: [:], method: .get)
	}

	static func json(_ pds: MockPDS, _ path: String) async throws -> [String: Any] {
		let response = try await pds.response(get(path), authedDid: nil)
		#expect(response.response.status == .ok)
		return try object(response.data)
	}

	static func object(_ data: Data) throws -> [String: Any] {
		try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
	}

	static func metadataBody(_ authorizationServer: MockAS) async throws -> Data {
		try await authorizationServer.fetcher.data(
			for: .init(url: authorizationServer.url(for: .metadata))
		).data
	}
}
