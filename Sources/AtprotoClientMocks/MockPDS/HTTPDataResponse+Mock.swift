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

	static func mock(encoding value: some Encodable) throws -> Self {
		.mock(json: try JSONEncoder().encode(value))
	}
}
