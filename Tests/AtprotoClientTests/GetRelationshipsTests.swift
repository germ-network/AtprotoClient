//
//  GetRelationshipsTests.swift
//  AtprotoClientTests
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP
import HTTPTypes
import Testing

import struct AtprotoClientMocks.StubHTTPFetcher

@testable import AtprotoClient

/// Thread-safe call counter - `StubHTTPFetcher`'s handler is synchronous but
/// invoked from concurrent async call sites.
private final class CallCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var value = 0

	@discardableResult
	func increment() -> Int {
		lock.lock()
		defer { lock.unlock() }
		value += 1
		return value
	}

	var count: Int {
		lock.lock()
		defer { lock.unlock() }
		return value
	}
}

private func xrpcURL(
	_ serviceUrl: URL,
	nsid: String,
	queryItems: [URLQueryItem]
) -> URL {
	var components = URLComponents(url: serviceUrl, resolvingAgainstBaseURL: false)!
	components.path = "/xrpc/\(nsid)"
	components.queryItems = queryItems
	return components.url!
}

@Suite struct GetRelationshipsParametersTests {
	private static let maxOthers = Lexicon.App.Bsky.Graph.GetRelationships.Parameters.maxOthers

	@Test("Exactly maxOthers (30) is accepted - the lexicon's others.maxLength")
	func exactlyMaxOthersIsAccepted() throws {
		let others = (0..<Self.maxOthers).map {
			LexiconString.AtIdentifier.did(
				.init(method: .plc, identifier: "subject\($0)"))
		}
		_ = try Lexicon.App.Bsky.Graph.GetRelationships.Parameters(
			actor: .did(.init(method: .plc, identifier: "actor")),
			others: others
		)
	}

	@Test("One more than maxOthers throws")
	func oneMoreThanMaxOthersThrows() throws {
		let others = (0...Self.maxOthers).map {
			LexiconString.AtIdentifier.did(
				.init(method: .plc, identifier: "subject\($0)"))
		}
		#expect(
			throws: Lexicon.App.Bsky.Graph.GetRelationships.Errors.tooManyOthersInput
		) {
			try Lexicon.App.Bsky.Graph.GetRelationships.Parameters(
				actor: .did(.init(method: .plc, identifier: "actor")),
				others: others
			)
		}
	}
}

@Suite struct RelationshipLookupTests {
	private let appViewURL = URL(string: "https://appview.example.com")!

	private func agent(fetcher: HTTPFetcher) throws -> BskyAppViewAgent {
		try BskyAppViewAgent(serviceUrl: appViewURL, resourceFetcher: fetcher)
	}

	@Test("relationshipLookup splits found vs. not-found subjects")
	func splitsFoundAndNotFound() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let foundDID = Atproto.DID(method: .plc, identifier: "bbbbbbbbbbbbbbbbbbbbbbbb")
		let notFoundDID = Atproto.DID(method: .plc, identifier: "cccccccccccccccccccccccc")
		let requestURL = xrpcURL(
			appViewURL, nsid: "app.bsky.graph.getRelationships",
			queryItems: [
				.init(name: "actor", value: actor.rawValue),
				.init(name: "others", value: foundDID.rawValue),
				.init(name: "others", value: notFoundDID.rawValue),
			])
		let counter = CallCounter()
		let fetcher = StubHTTPFetcher { request in
			counter.increment()
			#expect(request.request.url == requestURL)
			return .init(
				data: Data(
					"""
					{"actor":"\(actor.rawValue)","relationships":[
					{"$type":"app.bsky.graph.defs#relationship","did":"\(foundDID.rawValue)"},
					{"$type":"app.bsky.graph.defs#notFoundActor","actor":"\(notFoundDID.rawValue)","notFound":true}
					]}
					""".utf8),
				response: .init(status: .ok))
		}

		let result = try await agent(fetcher: fetcher).relationshipLookup(
			actor: actor, others: [foundDID, notFoundDID])

		#expect(result.found[foundDID]?.did == foundDID)
		#expect(result.notFound == [notFoundDID])
		#expect(counter.count == 1)
	}

	@Test(
		"An unrequested subject is dropped, a handle-form not-found and an omitted subject both land in notFound"
	)
	func dropsUnrequestedAndReportsHandleFormAndOmitted() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let a = Atproto.DID(method: .plc, identifier: "bbbbbbbbbbbbbbbbbbbbbbbb")
		let b = Atproto.DID(method: .plc, identifier: "cccccccccccccccccccccccc")
		let c = Atproto.DID(method: .plc, identifier: "dddddddddddddddddddddddd")
		let requestURL = xrpcURL(
			appViewURL, nsid: "app.bsky.graph.getRelationships",
			queryItems: [
				.init(name: "actor", value: actor.rawValue),
				.init(name: "others", value: a.rawValue),
				.init(name: "others", value: b.rawValue),
				.init(name: "others", value: c.rawValue),
			])
		// b reported not-found by handle; c omitted entirely; an unrequested
		// DID is returned alongside the legitimately-found a.
		let fetcher = StubHTTPFetcher { request in
			#expect(request.request.url == requestURL)
			return .init(
				data: Data(
					"""
					{"actor":"\(actor.rawValue)","relationships":[
					{"$type":"app.bsky.graph.defs#relationship","did":"\(a.rawValue)"},
					{"$type":"app.bsky.graph.defs#notFoundActor","actor":"bob.example.com","notFound":true},
					{"$type":"app.bsky.graph.defs#relationship","did":"did:plc:zzzzzzzzzzzzzzzzzzzzzzzz"}
					]}
					""".utf8),
				response: .init(status: .ok))
		}

		let result = try await agent(fetcher: fetcher)
			.relationshipLookup(actor: actor, others: [a, b, c])

		#expect(Set(result.found.keys) == [a])
		#expect(Set(result.notFound) == [b, c])
	}

	@Test("Duplicate subjects are sent once and reported once, whether found or not")
	func dedupesSubjects() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let foundDID = Atproto.DID(method: .plc, identifier: "bbbbbbbbbbbbbbbbbbbbbbbb")
		let notFoundDID = Atproto.DID(method: .plc, identifier: "cccccccccccccccccccccccc")
		let requestURL = xrpcURL(
			appViewURL, nsid: "app.bsky.graph.getRelationships",
			queryItems: [
				.init(name: "actor", value: actor.rawValue),
				.init(name: "others", value: foundDID.rawValue),
				.init(name: "others", value: notFoundDID.rawValue),
			])
		let counter = CallCounter()
		let fetcher = StubHTTPFetcher { request in
			counter.increment()
			// Exactly one `others` query item per subject - a request built
			// from undeduped input would carry each of them repeatedly and
			// fail to match.
			#expect(request.request.url == requestURL)
			// notFoundDID is omitted entirely - it's requested three times
			// below but must be reported as not-found exactly once, not once
			// per duplicate.
			return .init(
				data: Data(
					"""
					{"actor":"\(actor.rawValue)","relationships":[
					{"$type":"app.bsky.graph.defs#relationship","did":"\(foundDID.rawValue)"}
					]}
					""".utf8),
				response: .init(status: .ok))
		}

		let result = try await agent(fetcher: fetcher)
			.relationshipLookup(
				actor: actor,
				others: [
					foundDID, foundDID, notFoundDID, notFoundDID, notFoundDID,
				])

		#expect(counter.count == 1)
		#expect(result.found.count == 1)
		#expect(result.notFound == [notFoundDID])
	}

	@Test("A mismatched actor in the response throws actorMismatch")
	func mismatchedActorThrows() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let wrongActor = Atproto.DID(method: .plc, identifier: "ffffffffffffffffffffffff")
		let other = Atproto.DID(method: .plc, identifier: "bbbbbbbbbbbbbbbbbbbbbbbb")
		let fetcher = StubHTTPFetcher(
			.init(
				data: Data(
					"{\"actor\":\"\(wrongActor.rawValue)\",\"relationships\":[]}"
						.utf8),
				response: .init(status: .ok)))

		await #expect(
			throws: Lexicon.App.Bsky.Graph.GetRelationships.Errors.actorMismatch(
				requested: actor, returned: wrongActor)
		) {
			try await agent(fetcher: fetcher)
				.relationshipLookup(actor: actor, others: [other])
		}
	}

	@Test("A mismatched actor on a later chunk (not just the first) throws actorMismatch")
	func mismatchedActorOnLaterChunkThrows() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let wrongActor = Atproto.DID(method: .plc, identifier: "ffffffffffffffffffffffff")
		// 31 subjects -> 2 chunks; the first chunk's response names the
		// correct actor, so a check that only looks at the first chunk would
		// miss the mismatch on the second.
		let subjects = (0..<31).map {
			Atproto.DID(method: .plc, identifier: "subject\($0)")
		}
		let counter = CallCounter()
		let fetcher = StubHTTPFetcher { request in
			let requestNumber = counter.increment()
			let respondingActor = requestNumber == 1 ? actor : wrongActor
			return .init(
				data: Data(
					"{\"actor\":\"\(respondingActor.rawValue)\",\"relationships\":[]}"
						.utf8),
				response: .init(status: .ok))
		}

		await #expect(
			throws: Lexicon.App.Bsky.Graph.GetRelationships.Errors.actorMismatch(
				requested: actor, returned: wrongActor)
		) {
			try await agent(fetcher: fetcher)
				.relationshipLookup(actor: actor, others: subjects)
		}
		#expect(counter.count == 2)
	}

	@Test("Empty others returns an empty result without any request")
	func emptyOthersMakesNoRequest() async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let counter = CallCounter()
		let fetcher = StubHTTPFetcher { request in
			counter.increment()
			Issue.record("expected no request for empty others")
			return .init(data: Data(), response: .init(status: .ok))
		}

		let result = try await agent(fetcher: fetcher)
			.relationshipLookup(actor: actor, others: [])

		#expect(result.found.isEmpty)
		#expect(result.notFound.isEmpty)
		#expect(counter.count == 0)
	}

	/// Thread-safe collector for each request's `others` DIDs, in call order.
	private final class ChunkCollector: @unchecked Sendable {
		private let lock = NSLock()
		private var chunks: [[String]] = []

		func append(_ chunk: [String]) {
			lock.lock()
			defer { lock.unlock() }
			chunks.append(chunk)
		}

		var all: [[String]] {
			lock.lock()
			defer { lock.unlock() }
			return chunks
		}
	}

	@Test(
		"others are chunked at maxOthers (30 -> 1 request, 31 -> 2, 60 -> 2, 61 -> 3), each request carries at most 30, and the chunks concatenate back to the original order",
		arguments: [(30, 1), (31, 2), (60, 2), (61, 3)]
	)
	func chunksAtMaxOthers(_ subjectsAndRequests: (subjects: Int, requests: Int)) async throws {
		let actor = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let subjects = (0..<subjectsAndRequests.subjects).map {
			Atproto.DID(method: .plc, identifier: "subject\($0)")
		}
		let counter = CallCounter()
		let collector = ChunkCollector()
		let fetcher = StubHTTPFetcher { request in
			counter.increment()
			let url = request.request.url!
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
			let others =
				components.queryItems?
				.filter { $0.name == "others" }
				.compactMap(\.value) ?? []
			// The lexicon's own others.maxLength, not the subject total -
			// comparing against the subject total would pass even if
			// chunking were broken (e.g. one oversized request).
			#expect(
				others.count
					<= Lexicon.App.Bsky.Graph.GetRelationships.Parameters
					.maxOthers)
			collector.append(others)
			let entries = others.map {
				"{\"$type\":\"app.bsky.graph.defs#relationship\",\"did\":\"\($0)\"}"
			}.joined(separator: ",")
			return .init(
				data: Data(
					"{\"actor\":\"\(actor.rawValue)\",\"relationships\":[\(entries)]}"
						.utf8),
				response: .init(status: .ok))
		}

		let result = try await agent(fetcher: fetcher)
			.relationshipLookup(actor: actor, others: subjects)

		#expect(counter.count == subjectsAndRequests.requests)
		#expect(result.found.count == subjectsAndRequests.subjects)
		#expect(result.notFound.isEmpty)
		#expect(collector.all.flatMap { $0 } == subjects.map(\.rawValue))
	}
}

@Suite struct RelationshipsCodingTests {
	@Test("Decodes the lexicon's camel-cased list-block keys")
	func decodesListBlockKeys() throws {
		let json = """
			{
			  "$type": "app.bsky.graph.defs#relationship",
			  "did": "did:plc:subject",
			  "blockedByList": "at://did:plc:subject/app.bsky.graph.listblock/a",
			  "blockingByList": "at://did:plc:actor/app.bsky.graph.listblock/b"
			}
			"""
		let relationship = try JSONDecoder().decode(
			Lexicon.App.Bsky.Graph.Relationships.self,
			from: Data(json.utf8)
		)
		#expect(
			relationship.blockedByList?.rawValue
				== "at://did:plc:subject/app.bsky.graph.listblock/a")
		#expect(
			relationship.blockingbyList?.rawValue
				== "at://did:plc:actor/app.bsky.graph.listblock/b")
	}

	@Test("Encodes blockingByList under the lexicon's key")
	func encodesBlockingByListKey() throws {
		let relationship = Lexicon.App.Bsky.Graph.Relationships(
			did: .init(method: .plc, identifier: "subject"),
			blocking: nil,
			blockedBy: nil,
			following: nil,
			followedBy: nil,
			blockedByList: nil,
			blockingbyList: try .init(
				string: "at://did:plc:actor/app.bsky.graph.listblock/b")
		)
		let object = try #require(
			JSONSerialization.jsonObject(with: JSONEncoder().encode(relationship))
				as? [String: Any])
		#expect(object["blockingByList"] != nil)
		#expect(object["blockingbyList"] == nil)
	}
}
