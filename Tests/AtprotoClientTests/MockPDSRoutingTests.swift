//
//  MockPDSRoutingTests.swift
//  AtprotoClientTests
//
//  How `MockPDS.response(for:authedDid:)` routes a raw request, as a host-level
//  router hands it one. Routing is by path: `/xrpc/` is XRPC and carries the
//  XRPC error envelope; anything else the PDS does not serve is a plain 404.
//

import AtprotoClient
import AtprotoClientMocks
import AtprotoTypes
import Foundation
import GermConvenienceHTTP
import Testing

struct MockPDSRoutingTests {
	@Test(
		"a path outside /xrpc/ that the PDS does not serve is a plain 404",
		arguments: ["/", "/xrpc", "/foo", "/.well-known/atproto-did"]
	)
	func unservedPathIsNotFound(path: String) async throws {
		let pds = try MockPDS()

		let response = try await pds.response(
			for: .init(url: pds.serviceUrl.appending(path: path)),
			authedDid: nil
		)

		#expect(response.response.status == .notFound)
		#expect(response.data.isEmpty)
	}

	@Test("XRPC through the raw entry point reads what the agent wrote")
	func rawXrpcRequestIsServed() async throws {
		let (pds, did, agent) = try await MockPDSFixture.hosted()
		let subject = Atproto.DID.mock()
		let output = try await agent.createRecord(
			Lexicon.App.Bsky.Graph.Block(subject: subject, createdAt: .now)
		)

		var components = try #require(
			URLComponents(
				url: pds.serviceUrl.appending(
					path: "xrpc/com.atproto.repo.getRecord"),
				resolvingAgainstBaseURL: false
			)
		)
		components.queryItems = [
			.init(name: "repo", value: did.rawValue),
			.init(name: "collection", value: "app.bsky.graph.block"),
			.init(name: "rkey", value: try MockPDSFixture.rkey(of: output).rawValue),
		]

		let response = try await pds.response(
			for: .init(url: try #require(components.url)),
			authedDid: nil
		)

		#expect(response.response.status == .ok)
		let body = try #require(
			try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
		)
		let value = try #require(body["value"] as? [String: Any])
		#expect(value["subject"] as? String == subject.rawValue)
	}
}
