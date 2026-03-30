//
//  Procedure.swift
//  AtprotoClient
//
//  Created by Anna Mistele on 3/5/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes

extension AtprotoAgent {
	//most procedures don't have a queryParams
	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		bodyParams: X.BodyParameters,
	) async throws -> X.Output where X.Parameters == EmptyParameters {
		try await call(
			procedure,
			queryParams: .init(),
			bodyParams: bodyParams
		)
	}

	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		bodyParams: X.BodyParameters,
	) async throws -> X.Output {
		let request = try constructRequest(
			procedure,
			queryParams: queryParams,
			bodyParams: bodyParams
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

	//breaking this apart lets us inject proxying
	func constructRequest<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		bodyParams: X.BodyParameters,
	) throws -> XRPCRequestComponents {
		.init(
			relativePath: "/xrpc/" + X.nsid,
			queryItems: queryParams.asQueryItems(),
			headers: .init(
				dictionaryLiteral: (.accept, X.acceptValue),
				(.contentType, X.contentTypeValue)
			),
			method: .post,
			body: try bodyParams.httpBody()
		)
	}
}
