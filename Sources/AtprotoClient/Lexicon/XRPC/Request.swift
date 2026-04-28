//
//  Request.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 2/27/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

extension Atproto.XRPC.Callable {
	public func call<X: Atproto.XRPC.Request>(
		_ request: X.Type,
		parameters: X.Parameters,
	) async throws -> X.Output {
		let request = try constructRequest(
			request,
			parameters: parameters
		)

		return try await response(request)
			.parse(X.self)
	}

	func constructRequest<X: Atproto.XRPC.Request>(
		_ request: X.Type,
		parameters: X.Parameters,
	) throws -> XRPCRequestComponents {
		.init(
			relativePath: "/xrpc/" + X.Id.nsid.rawValue,
			queryItems: parameters.asQueryItems(),
			headers: .init(
				dictionaryLiteral: (.accept, X.outputEncoding.rawValue)
			),
			method: .get,
		)
	}
}
