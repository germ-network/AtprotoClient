//
//  XRPCProxyCallable.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import AtprotoTypes
import Foundation

//an implementation (e.g. auth'd PDS) can declare itself capable of proxying requests
public protocol XRPCProxyCallable: XRPCCallable {}

extension XRPCProxyCallable {
	public func call<X: XRPCRequest>(
		_ request: X.Type,
		parameters: X.Parameters,
		proxy: ProxyService
	) async throws -> X.Output {
		var request = try constructRequest(request, parameters: parameters)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy.headerValue

		return try await response(request)
			.parse(X.self)
	}
}

extension XRPCProxyCallable where Self: XRPCAuthCallable {
	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		input: X.Input,
		proxy: ProxyService
	) async throws -> X.Output {
		var request = try constructRequest(
			procedure,
			queryParams: queryParams,
			input: input
		)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy.headerValue

		return try await response(request)
			.parse(X.self)
	}
}
