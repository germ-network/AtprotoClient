//
//  DoHTXTFetcher.swift
//  AtprotoClient
//

import Foundation
import GermConvenience
import GermConvenienceHTTP

/// RFC 8484 DNS-over-HTTPS TXT lookups over the existing `HTTPFetcher` seam.
///
/// Portable - no platform dependency, so this is usable on every platform
/// this package supports, including ones with no per-app system resolver
/// policy to inherit from a platform-specific conformer.
public struct DoHTXTFetcher: DNSTXTFetcher {
	public static let cloudflare = URL(string: "https://cloudflare-dns.com/dns-query")!
	public static let google = URL(string: "https://dns.google/dns-query")!
	/// Cloudflare first, Google as fallback if the former is blocked or down.
	public static let defaultProviders = [cloudflare, google]

	let fetcher: any HTTPFetcher
	let serverURLs: [URL]
	let timeout: Duration

	/// `serverURLs` is a plain, ordered list of providers to try in turn - not
	/// hardcoded to `defaultProviders` - so a caller can point this at a
	/// self-hosted or region-specific DoH resolver instead.
	public init(
		fetcher: any HTTPFetcher,
		serverURLs: [URL] = DoHTXTFetcher.defaultProviders,
		timeout: Duration = .seconds(5)
	) {
		self.fetcher = fetcher
		self.serverURLs = serverURLs
		self.timeout = timeout
	}

	/// Tries each provider in order. Only advances on failure - a network error,
	/// a non-2xx, a malformed response, or that provider's own timeout. A clean
	/// NXDOMAIN is a real answer (no record), not a reason to try the next host.
	public func txtRecords(name: String) async throws -> [String] {
		guard !serverURLs.isEmpty else {
			throw DNSTXTFetcherError.noProvidersConfigured
		}

		let query = try DNSWireFormat.encodeTXTQuery(name: name)
		var lastError: any Error = DNSTXTFetcherError.timedOut

		for serverURL in serverURLs {
			//a cancelled caller is not a failing provider: without this the
			//loop would burn through every remaining server, each cancelled
			//in turn, before reporting the cancellation.
			try Task.checkCancellation()
			do {
				return try await queryOneServer(url: serverURL, query: query)
			} catch DNSTXTFetcherError.nameError {
				return []
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				lastError = error
			}
		}
		throw lastError
	}

	/// Races the network request against `timeout`; cancels whichever loses.
	private func queryOneServer(url: URL, query: Data) async throws -> [String] {
		try await withThrowingTaskGroup(of: [String].self) { group in
			defer { group.cancelAll() }

			group.addTask { try await self.performQuery(url: url, query: query) }
			group.addTask {
				try await Task.sleep(for: self.timeout)
				throw DNSTXTFetcherError.timedOut
			}

			guard let result = try await group.next() else {
				throw DNSTXTFetcherError.timedOut
			}
			return result
		}
	}

	private func performQuery(url: URL, query: Data) async throws -> [String] {
		let request = try BundledHTTPRequest(
			method: .post,
			url: url,
			headerFields: [
				.contentType: "application/dns-message",
				.accept: "application/dns-message",
			],
			body: query
		)
		let data = try await fetcher.data(for: request).expectSuccess()

		do {
			return try DNSWireFormat.decodeTXTRecords(data)
		} catch let decodeError as DNSWireFormat.DecodeError {
			switch decodeError {
			case .nameError:
				throw DNSTXTFetcherError.nameError
			case .serverFailure(let rcode):
				throw DNSTXTFetcherError.serverError(rcode: rcode)
			case .truncated, .compressionPointerLoop, .malformedLabel:
				throw DNSTXTFetcherError.malformedResponse(decodeError)
			}
		}
	}
}
