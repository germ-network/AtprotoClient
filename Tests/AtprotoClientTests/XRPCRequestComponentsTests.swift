//
//  XRPCRequestComponentsTests.swift
//  AtprotoClientTests
//
//  The URL `constructUrl` builds: the path replaces the service URL's
//  wholesale, and a query string only appears when there are query items.
//

import AtprotoClient
import Foundation
import Testing

struct XRPCRequestComponentsTests {
	let serviceUrl = URL(string: "https://pds.example.com/ignored/prefix")!

	@Test("no query items means no query string, not a bare ?")
	func emptyQueryItemsOmitTheQuery() throws {
		let request = try XRPCRequestComponents(
			relativePath: "/xrpc/com.atproto.server.describeServer",
			queryItems: [],
			headers: [:],
			method: .get
		).constructUrl(serviceUrl: serviceUrl)

		#expect(
			request.request.url?.absoluteString
				== "https://pds.example.com/xrpc/com.atproto.server.describeServer"
		)
	}

	@Test("query items are carried as the query string")
	func queryItemsAreEncoded() throws {
		let request = try XRPCRequestComponents(
			relativePath: "/xrpc/com.atproto.repo.getRecord",
			queryItems: [
				.init(name: "repo", value: "did:plc:abc"),
				.init(name: "rkey", value: "self"),
			],
			headers: [:],
			method: .get
		).constructUrl(serviceUrl: serviceUrl)

		#expect(
			request.request.url?.absoluteString
				== "https://pds.example.com/xrpc/com.atproto.repo.getRecord?repo=did:plc:abc&rkey=self"
		)
	}
}
