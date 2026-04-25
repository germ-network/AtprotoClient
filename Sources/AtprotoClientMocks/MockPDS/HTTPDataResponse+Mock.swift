//
//  HTTPDataResponse+Mock.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 4/9/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

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
}
