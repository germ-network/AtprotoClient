//
//  DoHTXTFetcherTests.swift
//  AtprotoClientTests
//

import Foundation
import GermConvenience
import GermConvenienceHTTP
import Testing

@testable import AtprotoClient

private final class ScriptedFetcher: HTTPFetcher, @unchecked Sendable {
	enum Behavior {
		case response(HTTPDataResponse)
		/// Never returns until its Task is cancelled - for the cancellation test.
		case hang
	}

	private let lock = NSLock()
	private var behaviors: [Behavior]
	private var _requestedRequests: [BundledHTTPRequest] = []

	/// Read from the test body while a hung request may still be in flight, so
	/// it takes the same lock the fetcher writes under.
	var requestedRequests: [BundledHTTPRequest] { lock.withLock { _requestedRequests } }
	var requestedURLs: [URL] { requestedRequests.map { $0.request.url! } }

	init(_ behaviors: [Behavior]) {
		self.behaviors = behaviors
	}

	func data(for request: BundledHTTPRequest) async throws -> HTTPDataResponse {
		let behavior = lock.withLock {
			let index = _requestedRequests.count
			_requestedRequests.append(request)
			return index < behaviors.count
				? behaviors[index] : behaviors[behaviors.count - 1]
		}

		switch behavior {
		case .response(let response):
			return response
		case .hang:
			try await Task.sleep(for: .seconds(3600))
			throw CancellationError()
		}
	}
}

private let cloudflare = DoHTXTFetcher.cloudflare
private let google = DoHTXTFetcher.google

struct DoHTXTFetcherTests {

	@Test func requestShapeIsRFC8484POST() async throws {
		let responseData = DNSFixtures.txtResponse(
			question: "_atproto.example.com", text: "did=did:plc:abc")
		let fetcher = ScriptedFetcher([
			.response(.init(data: responseData, response: .init(status: .ok)))
		])
		let txtFetcher = DoHTXTFetcher(fetcher: fetcher, serverURLs: [cloudflare])

		_ = try await txtFetcher.txtRecords(name: "_atproto.example.com")

		let sent = try #require(fetcher.requestedRequests.first)
		#expect(sent.request.method == .post)
		#expect(sent.request.headerFields[.contentType] == "application/dns-message")
		#expect(sent.request.headerFields[.accept] == "application/dns-message")
		#expect(
			sent.body
				== (try DNSWireFormat.encodeTXTQuery(name: "_atproto.example.com")))

		#expect(fetcher.requestedURLs == [cloudflare])
	}

	@Test func parsesTheDidFromASuccessfulResponse() async throws {
		let responseData = DNSFixtures.txtResponse(
			question: "_atproto.example.com", text: "did=did:plc:abc123")
		let fetcher = ScriptedFetcher([
			.response(.init(data: responseData, response: .init(status: .ok)))
		])
		let txtFetcher = DoHTXTFetcher(fetcher: fetcher, serverURLs: [cloudflare])

		let records = try await txtFetcher.txtRecords(name: "_atproto.example.com")

		#expect(records == ["did=did:plc:abc123"])
	}

	// MARK: - fallback order

	@Test func advancesToTheNextProviderOnFailure() async throws {
		let responseData = DNSFixtures.txtResponse(
			question: "_atproto.example.com", text: "did=did:plc:fromgoogle")
		let fetcher = ScriptedFetcher([
			.response(
				.init(data: Data(), response: .init(status: .internalServerError))),
			.response(.init(data: responseData, response: .init(status: .ok))),
		])
		let txtFetcher = DoHTXTFetcher(fetcher: fetcher, serverURLs: [cloudflare, google])

		let records = try await txtFetcher.txtRecords(name: "_atproto.example.com")

		#expect(records == ["did=did:plc:fromgoogle"])
		#expect(fetcher.requestedURLs == [cloudflare, google])
	}

	@Test func aCleanNXDOMAINIsTheAnswerNotAReasonToTryTheNextProvider() async throws {
		let nxdomain = DNSFixtures.nxdomainResponse(question: "_atproto.example.com")
		let fetcher = ScriptedFetcher([
			.response(.init(data: nxdomain, response: .init(status: .ok)))
		])
		let txtFetcher = DoHTXTFetcher(fetcher: fetcher, serverURLs: [cloudflare, google])

		let records = try await txtFetcher.txtRecords(name: "_atproto.example.com")

		#expect(records.isEmpty)
		#expect(fetcher.requestedURLs == [cloudflare])
	}

	@Test func throwsAfterExhaustingEveryProvider() async {
		let fetcher = ScriptedFetcher([
			.response(
				.init(data: Data(), response: .init(status: .internalServerError))),
			.response(
				.init(data: Data(), response: .init(status: .internalServerError))),
		])
		let txtFetcher = DoHTXTFetcher(fetcher: fetcher, serverURLs: [cloudflare, google])

		await #expect(throws: (any Error).self) {
			try await txtFetcher.txtRecords(name: "_atproto.example.com")
		}
		#expect(fetcher.requestedURLs == [cloudflare, google])
	}

	// MARK: - timeout and cancellation

	@Test func aSlowProviderTimesOutAndFallsThroughToTheNext() async throws {
		let responseData = DNSFixtures.txtResponse(
			question: "_atproto.example.com", text: "did=did:plc:secondserver")
		let fetcher = ScriptedFetcher([
			.hang,
			.response(.init(data: responseData, response: .init(status: .ok))),
		])
		let txtFetcher = DoHTXTFetcher(
			fetcher: fetcher, serverURLs: [cloudflare, google],
			timeout: .milliseconds(100))

		let records = try await txtFetcher.txtRecords(name: "_atproto.example.com")

		#expect(records == ["did=did:plc:secondserver"])
	}

	// Cancel before the task's body has any chance to run: `Task.checkCancellation()`
	// at the top of the provider loop and the dedicated `catch is CancellationError`
	// in `txtRecords` both exist so a cancelled caller reports cancellation
	// immediately rather than burning through the remaining providers first, or
	// having the `.hang` fetcher's own `CancellationError` misread as "this
	// provider failed, try the next one."
	@Test func taskCancellationInterruptsPromptly() async throws {
		let fetcher = ScriptedFetcher([.hang])
		let txtFetcher = DoHTXTFetcher(
			fetcher: fetcher, serverURLs: [cloudflare, google], timeout: .seconds(30))

		let task = Task {
			try await txtFetcher.txtRecords(name: "_atproto.example.com")
		}
		task.cancel()

		let result = await task.result
		#expect(throws: CancellationError.self) { try result.get() }
		// the cancelled provider must not be treated as merely failed - a
		// regression here would try `google` next instead of stopping.
		#expect(fetcher.requestedURLs.count <= 1)
	}
}
