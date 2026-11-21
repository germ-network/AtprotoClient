//
//  MockServiceUrl.swift
//  AtprotoClientMocks
//

import Foundation
import GermConvenience

/// Hosts for mock services.
enum MockServiceUrl {
	/// A new random `https` host under example.com.
	///
	/// Lowercase, as `origin` lowercases hosts: a PDS that is its own
	/// authorization server derives its issuer from its `serviceUrl`'s origin,
	/// and the two must compare equal.
	static func random(subdomain: String? = nil) throws -> URL {
		let label = subdomain.map { ".\($0)" } ?? ""
		return try URL(
			string: "https://\(UUID().uuidString.lowercased())\(label).example.com"
		).unwrapped
	}
}
