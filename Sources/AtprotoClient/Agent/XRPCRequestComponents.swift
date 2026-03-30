//
//  XRPCRequestComponents.swift
//  AtprotoClient
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation
import GermConvenience
import HTTPTypes

public struct XRPCRequestComponents: Sendable {
	public var relativePath: String
	public var queryItems: [URLQueryItem]
	public var headers: HTTPFields
	public var method: HTTPRequest.Method
	public var body: Data?
	
	public init(
		relativePath: String,
		queryItems: [URLQueryItem],
		headers: HTTPFields,
		method: HTTPRequest.Method,
		body: Data? = nil
	) {
		self.relativePath = relativePath
		self.queryItems = queryItems
		self.headers = headers
		self.method = method
		self.body = body
	}
	
	public func constructUrl(serviceUrl: URL) throws -> BundledHTTPRequest {
		let constructedUrl = serviceUrl
			.appending(path: relativePath)
			.appending(queryItems: queryItems)
		
		return try .init(
			request: .init(
				method: method,
				url: constructedUrl,
				headerFields: headers
			),
			body: body
		)
	}
}
