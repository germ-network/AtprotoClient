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

		return try await response(request)
			.parse(X.self)
	}

	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		input: X.Input,
		proxy: String
	) async throws -> X.Output {
		var request = try constructRequest(
			procedure,
			queryParams: queryParams,
			input: input
		)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy

		return try await response(request)
			.parse(X.self)
	}
}
