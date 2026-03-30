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

extension AtprotoAgent {
	public func call<X: XRPCRequest>(
		_ request: X.Type,
		parameters: X.Parameters,
	) async throws -> X.Output {
		let request = try constructRequest(
			request,
			parameters: parameters
		)

		let result = try await response(request)
			.success(
				decodeResult: X.Output.self,
				orError: Lexicon.XRPCError.self
			)

		switch result {
		case .error(let errorStruct, let responseStatus):
			throw AtprotoClientError.requestFailed(
				responseStatus: responseStatus,
				error: errorStruct.error
			)
		case .result(let result):
			return result
		}
	}

	func constructRequest<X: XRPCRequest>(
		_ request: X.Type,
		parameters: X.Parameters,
	) throws -> XRPCRequestComponents {
		.init(
			relativePath: "/xrpc/" + X.nsid,
			queryItems: parameters.asQueryItems(),
			headers: .init(dictionaryLiteral: (.accept, X.acceptValue) ),
			method: .get,
		)
	}
}
