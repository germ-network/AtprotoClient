//
//  PutRecordSwapTests.swift
//  AtprotoClientTests
//

import AtprotoClient
import AtprotoTypes
import Foundation
import GermConvenienceHTTP
import HTTPTypes
import Testing

struct PutRecordSwapTests {
	/// Captures the request body, then refuses with `InvalidSwap` so no output needs building.
	final class RecordingCallable: Atproto.XRPC.AuthCallable, @unchecked Sendable {
		let did: Atproto.DID
		private let lock = NSLock()
		private var bodies: [Data] = []

		init(did: Atproto.DID) { self.did = did }

		var lastBody: Data? { lock.withLock { bodies.last } }

		func response(_ requestComponents: XRPCRequestComponents) async throws
			-> HTTPDataResponse
		{
			lock.withLock { bodies.append(requestComponents.body ?? Data()) }
			return HTTPDataResponse(
				data: Data(#"{"error":"InvalidSwap"}"#.utf8),
				response: HTTPResponse(status: .badRequest)
			)
		}
	}

	static let cidString = "bafyreibmcnkzbxtciyydktbatjlpgh5hollpov4zvpwtaaq353vyzfbxwu"

	private func sentBody(
		swap: Atproto.RecordSwap?,
		swapCommit: Atproto.CID? = nil
	) async throws -> [String: Any] {
		let callable = RecordingCallable(
			did: try .init(string: "did:plc:abcdefghijklmnopqrstuvwx")
		)
		let profile = Lexicon.App.Bsky.Actor.Profile(
			avatar: nil, banner: nil, createdAt: nil, description: nil,
			displayName: "x", pronouns: nil, website: nil
		)
		_ = try? await callable.putRecord(profile, swapCommit: swapCommit, swap: swap)
		let body = try #require(callable.lastBody)
		return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
	}

	@Test
	func absentSwapSendsNullSwapRecord() async throws {
		let body = try await sentBody(swap: .absent)
		#expect(body.keys.contains("swapRecord"))
		#expect(body["swapRecord"] is NSNull)
	}

	@Test
	func recordSwapSendsCidSwapRecord() async throws {
		let cid = try Atproto.CID(string: Self.cidString)
		let body = try await sentBody(swap: .record(cid), swapCommit: cid)
		#expect(body["swapRecord"] as? String == cid.string)
		#expect(body["swapCommit"] as? String == cid.string)
	}

	@Test
	func nilSwapOmitsSwapRecord() async throws {
		let body = try await sentBody(swap: nil)
		#expect(body.keys.contains("swapRecord") == false)
	}
}
