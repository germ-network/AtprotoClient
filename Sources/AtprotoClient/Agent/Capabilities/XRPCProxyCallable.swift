//
//  XRPCProxyCallable.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/28/26.
//

import AtprotoTypes
import Foundation

//an implementation (e.g. auth'd PDS) can declare itself capable of proxying requests
extension Atproto.XRPC {
	public protocol ProxyCallable: Callable {}
}

extension Atproto.XRPC.ProxyCallable {
	public func call<X: Atproto.XRPC.Request>(
		_ request: X.Type,
		parameters: X.Parameters,
		proxy: Atproto.Service
	) async throws -> X.Output {
		var request = try constructRequest(request, parameters: parameters)

		request.headers[try .atprotoProxy.tryUnwrap] = proxy.headerValue

		return try await response(request)
			.parse(X.self)
	}

	public func call<X: Atproto.XRPC.Procedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		input: X.Input,
		proxy: Atproto.Service
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
