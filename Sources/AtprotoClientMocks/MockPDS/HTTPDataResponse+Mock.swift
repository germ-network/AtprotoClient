//
//  HTTPDataResponse+Mock.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/9/26.
//

import AtprotoTypes
import Foundation
import GermConvenience

import struct HTTPTypes.HTTPResponse

//returning an error instead of throwing reduces noise for tests
extension HTTPDataResponse {
	static func mock(
		errorObject: Atproto.XRPC.ErrorResponse,
		status: HTTPResponse.Status
	) throws -> Self {
		.init(
			data: try JSONEncoder().encode(errorObject),
			response: .init(status: status)
		)
	}

	static func mock(
		error: String,
		status: HTTPResponse.Status
	) throws -> Self {
		try .mock(
			errorObject: .init(error: error, message: "Mock Error"),
			status: status
		)
	}

	//Every success the mock returns carries the same envelope — 200, JSON content
	//type — and five sites were building it by hand. One builder means a change to
	//the envelope reaches all of them.
	static func mock(json: Data) -> Self {
		.init(
			data: json,
			response: .init(
				status: .ok,
				headerFields: .init(
					[
						.init(
							name: .contentType,
							value: HTTPContentType.json.rawValue
						)
					]
				)
			)
		)
	}

	//`Data` is itself Encodable, so an already-encoded body handed to this would
	//otherwise be re-encoded as a base64 string. Pass it through instead, the way
	//GermConvenience's `Data.decode` special-cases the same type on the way in. An
	//`@available(*, unavailable)` overload does NOT close this: the generic is
	//still available, so it wins resolution and the call compiles silently.
	static func mock(encoding value: some Encodable) throws -> Self {
		if let json = value as? Data {
			return .mock(json: json)
		}
		return .mock(json: try JSONEncoder().encode(value))
	}
}
