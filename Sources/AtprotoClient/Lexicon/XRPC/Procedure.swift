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
		input: X.Input,
	) async throws -> X.Output where X.Parameters == EmptyXRPCParameters {
		try await call(
			procedure,
			queryParams: .init(),
			input: input
		)
	}
	
	public func call<X: XRPCProcedure>(
		_ procedure: X.Type,
		queryParams: X.Parameters,
		input: X.Input,
	) async throws -> X.Output {
		let request = try constructRequest(
			procedure,
			queryParams: queryParams,
			input: input
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
		input: X.Input,
	) throws -> XRPCRequestComponents {
		var headerFields = HTTPFields()
		headerFields[.accept] = X.acceptValue.rawValue
		if X.Input.encoding != .none {
			headerFields[.contentType] = X.Input.encoding.rawValue
		}
		
		return .init(
			relativePath: "/xrpc/" + X.nsid,
			queryItems: queryParams.asQueryItems(),
			headers: headerFields,
			method: .post,
			body: try X.Input.encode(input.schema)
		)
	}
}
