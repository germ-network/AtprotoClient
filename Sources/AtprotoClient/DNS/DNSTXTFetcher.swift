//
//  DNSTXTFetcher.swift
//  AtprotoClient
//

import Foundation

/// Resolves TXT records for a fully-qualified name.
///
/// Mirrors `HTTPFetcher`'s shape: a narrow protocol so the caller can inject a
/// platform conformer, a mock, or a platform's own system resolver.
public protocol DNSTXTFetcher: Sendable {
	/// The strings of every TXT record found for `name`, one entry per record.
	/// A record's own length-prefixed character-strings are already joined.
	/// Empty when the name resolves but carries no TXT record (NXDOMAIN or NODATA).
	func txtRecords(name: String) async throws -> [String]
}

public enum DNSTXTFetcherError: LocalizedError, Equatable, Sendable {
	/// The name does not exist.
	case nameError
	/// The response's RCODE was neither success (0) nor NXDOMAIN (3).
	case serverError(rcode: UInt8)
	/// Ran past the caller's `timeout` without an answer.
	case timedOut
	/// Malformed DNS wire-format response - see `DNSWireFormat.DecodeError`.
	case malformedResponse(DNSWireFormat.DecodeError)
	/// A platform system resolver reported failure with its own error code -
	/// not a DNS RCODE, so kept distinct from `serverError`. Unused by any
	/// conformer in this package today; kept so a platform-specific conformer
	/// added later doesn't need a breaking change to this enum.
	case resolverFailure(code: Int32)
	/// `DoHTXTFetcher` was constructed with no providers to try - a caller
	/// misconfiguration, not a network failure, so kept distinct from `timedOut`.
	case noProvidersConfigured

	public var errorDescription: String? {
		switch self {
		case .nameError: "DNS name does not exist"
		case .serverError(let rcode): "DNS server returned RCODE \(rcode)"
		case .timedOut: "DNS query timed out"
		case .malformedResponse(let error): "Malformed DNS response: \(error)"
		case .resolverFailure(let code): "Platform resolver failed with code \(code)"
		case .noProvidersConfigured: "No DoH providers configured"
		}
	}
}
