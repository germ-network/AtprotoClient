//
//  HTTPDataResponseMockTests.swift
//  AtprotoClientTests
//
//  The shared success envelope every mock endpoint returns through.
//

import AtprotoTypes
import Foundation
import GermConvenience
import Testing

@testable import AtprotoClientMocks

struct HTTPDataResponseMockTests {
	/// `Data` conforms to `Encodable`, so handing an already-encoded body to
	/// `mock(encoding:)` would JSON-encode it a second time — into a base64 string
	/// — and the caller would get a body that decodes as nothing it expected. The
	/// overload passes Data through instead.
	///
	/// Worth pinning because the obvious guard does not work: an
	/// `@available(*, unavailable)` `Data` overload still loses to the generic one,
	/// and the misuse compiles silently.
	@Test("an already-encoded body is not encoded twice")
	func dataIsPassedThroughRatherThanReEncoded() throws {
		let body = Data(#"{"already":"json"}"#.utf8)

		let response = try HTTPDataResponse.mock(encoding: body)

		#expect(response.data == body)
		#expect(response.data != (try JSONEncoder().encode(body)))
	}

	@Test("the envelope is a 200 carrying JSON")
	func envelopeIsJSONOK() throws {
		let response = try HTTPDataResponse.mock(encoding: ["a": 1])

		#expect(response.response.status == .ok)
		#expect(
			response.response.headerFields[.contentType]
				== HTTPContentType.json.rawValue
		)
	}
}
