//
//  DnsHandleResolver.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP

extension Atproto {
	/// Resolves an atproto handle via its `_atproto` DNS TXT record, as
	/// specified at https://atproto.com/specs/handle#dns-txt-method.
	///
	/// Sibling to `WellKnownHandleResolver`: the two methods are independent
	/// and a caller resolving a handle should try both, per the spec.
	public struct DnsHandleResolver: Sendable {
		static let namePrefix = "_atproto."
		static let recordPrefix = "did="

		let txtFetcher: any DNSTXTFetcher

		/// `DoHTXTFetcher`, over a redirect-refusing `HTTPFetcher`, is the
		/// conformer this package ships - portable everywhere, unlike a
		/// platform system resolver. Pass a platform-specific `DNSTXTFetcher`
		/// to use one instead.
		public init(txtFetcher: any DNSTXTFetcher) {
			self.txtFetcher = txtFetcher
		}

		/// `nil` when the name resolves but carries no `did=`-prefixed TXT
		/// record; throws for a fetcher failure or a malformed DID value.
		public func resolve(handle: Atproto.Handle) async throws -> Atproto.DID? {
			let name = Self.namePrefix + handle.rawValue
			let records = try await txtFetcher.txtRecords(name: name)

			guard
				let didRecord = records.first(where: {
					$0.hasPrefix(Self.recordPrefix)
				})
			else {
				return nil
			}

			let didString = didRecord.dropFirst(Self.recordPrefix.count)
			return try Atproto.DID(string: String(didString))
		}
	}
}
