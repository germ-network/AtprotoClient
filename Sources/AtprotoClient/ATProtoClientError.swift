//
//  AtprotoClientError.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 2/17/26.
//

import AtprotoTypes
import Foundation
import HTTPTypes

enum AtprotoClientError: Error {
	case requestFailed(
		responseStatus: HTTPResponse.Status,
		error: Atproto.XRPC.ParseError
	)
}

extension AtprotoClientError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .requestFailed(let status, let errorString):
			"Request failed with response status: \(status), error \(errorString)"
		}
	}
}
