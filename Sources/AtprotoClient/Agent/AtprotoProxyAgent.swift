//
//  AtprotoProxyAgent.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import AtprotoTypes
import Foundation

//an implementation (e.g. auth'd PDS) can declare itself caxpable of proxying requests
public protocol AtprotoProxyAgent: AtprotoAgent {}

extension AtprotoProxyAgent {
	public func call<X: XRPCRequest>(
		_ request: X.Type,
		parameters: X.Parameters,
		proxy: String
	) async throws -> X.Output {
		var request = try constructRequest(request, parameters: parameters)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy

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

	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		bodyParams: X.BodyParameters,
		proxy: String
	) async throws -> X.Output {
		var request = try constructRequest(
			procedure,
			queryParams: queryParams,
			bodyParams: bodyParams
		)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy

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
}
