//
//  NotFoundStatusTests.swift
//  AtprotoClientTests
//
//  The optional-result path reads a miss as nil whichever status the PDS sends
//  it under: the reference PDS's 400, or the 404 tranquil sends.
//

import AtprotoClient
import AtprotoTypes
import Foundation
import GermConvenienceHTTP
import HTTPTypes
import Testing

struct NotFoundStatusTests {
	/// Answers every request with one canned response.
	struct Canned: Atproto.XRPC.Callable {
		let status: HTTPResponse.Status
		let body: String

		func response(_ requestComponents: XRPCRequestComponents) async throws
			-> HTTPDataResponse
		{
			var response = HTTPResponse(status: status)
			response.headerFields[.contentType] = "application/json"
			return HTTPDataResponse(data: Data(body.utf8), response: response)
		}
	}

	func getRecord(from agent: Canned) async throws
		-> Lexicon.Com.Atproto.Repo.GetRecord<Lexicon.App.Bsky.Graph.Block>.Output?
	{
		try await agent.callExpectingOptional(
			Lexicon.Com.Atproto.Repo.GetRecord<Lexicon.App.Bsky.Graph.Block>.self,
			parameters: .init(
				repo: .did(try .init(string: "did:plc:4yrypf6iqj2bdgrp7s47o5ns")),
				rkey: try .init(string: "3jzfcijpj2z2a"),
				cid: nil
			)
		)
	}

	@Test("a 404 RecordNotFound reads back as nil")
	func notFoundStatusIsNil() async throws {
		let agent = Canned(
			status: .notFound,
			body: #"{"error":"RecordNotFound","message":"Record not found"}"#)
		#expect(try await getRecord(from: agent) == nil)
	}

	@Test("a 400 RecordNotFound still reads back as nil")
	func badRequestStatusIsNil() async throws {
		let agent = Canned(
			status: .badRequest,
			body: #"{"error":"RecordNotFound","message":"Could not locate record"}"#)
		#expect(try await getRecord(from: agent) == nil)
	}

	@Test("a 404 naming another error stays an error")
	func otherNotFoundErrorThrows() async throws {
		let agent = Canned(
			status: .notFound,
			body: #"{"error":"RepoNotFound","message":"Repo not found"}"#)
		await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await getRecord(from: agent)
		}
	}

	@Test("a 404 without an XRPC error body stays an error")
	func bareNotFoundThrows() async throws {
		let agent = Canned(status: .notFound, body: "<html>Not Found</html>")
		await #expect(throws: Atproto.XRPC.ParseError.self) {
			try await getRecord(from: agent)
		}
	}
}
