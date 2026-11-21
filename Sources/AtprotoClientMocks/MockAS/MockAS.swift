//
//  MockAS.swift
//  AtprotoClient
//

import Foundation
import GermConvenience
import GermConvenienceHTTP
import GermConvenienceMocks

/// A mock OAuth authorization server. Its issuer is the origin of the host it
/// runs on: a PDS's own, when the PDS is its own authorization server, or a
/// separate entryway host. Every URL in its metadata is built from that issuer,
/// because OAuth discovery requires the `issuer` to exactly match the URL it
/// was fetched for.
///
/// Requests are answered by `fetcher`, which always serves the metadata. Script
/// the other endpoints on it per test, and read back what the client sent:
///
///     await authorizationServer.fetcher
///         .on(authorizationServer.url(for: .pushedAuthorizationRequest), method: .post)
///         .enqueue(.success(…))
///
/// One `MockAS` can back several `MockPDS`es, modelling an entryway in front of
/// many PDSes; they share its `fetcher`.
public struct MockAS: Sendable {
	/// The host this server runs on: a PDS's own, when the PDS is its own
	/// authorization server, or a separate entryway host.
	public let serviceUrl: URL
	/// `serviceUrl`'s origin: an issuer has no path or trailing slash, and
	/// discovery compares it exactly.
	public let issuerUrl: URL
	public let fetcher: MockHTTPFetcher

	/// Every URL this server advertises in its metadata, as a path under the
	/// issuer.
	public enum Endpoint: String, Sendable, CaseIterable {
		case metadata = ".well-known/oauth-authorization-server"
		case jwks = "oauth/jwks"
		case authorization = "oauth/authorize"
		case token = "oauth/token"
		case revocation = "oauth/revoke"
		case pushedAuthorizationRequest = "oauth/par"

		func url(issuer: URL) -> URL {
			issuer.appending(path: rawValue)
		}
	}

	public func url(for endpoint: Endpoint) -> URL {
		endpoint.url(issuer: issuerUrl)
	}

	/// Pass a PDS's `serviceUrl` to model a PDS that is its own authorization
	/// server. By default the service is a new random host.
	public init(serviceUrl: URL? = nil) throws {
		let serviceUrl = try serviceUrl ?? Self.makeServiceUrl()
		let issuerUrl = try URL(string: serviceUrl.origin).unwrapped
		self.serviceUrl = serviceUrl
		self.issuerUrl = issuerUrl
		//registered at creation, so a test's own `always` for the metadata
		//replaces it instead of being replaced by it
		self.fetcher = MockHTTPFetcher([
			.on(Endpoint.metadata.url(issuer: issuerUrl), method: .get)
				.always(.success(.mock(json: try Self.metadata(issuer: issuerUrl))))
		])
	}

	/// Whether `request` is addressed to this authorization server: its origin
	/// is the issuer's, and its path is one of `Endpoint`. A PDS that is its own
	/// authorization server shares the origin, so the path is what separates
	/// the two.
	public func handles(_ request: BundledHTTPRequest) throws -> Bool {
		let requestUrl = try request.request.url.unwrapped
		guard try requestUrl.origin == issuerUrl.origin else {
			return false
		}
		let path = requestUrl.path()
		return Endpoint.allCases.contains { url(for: $0).path() == path }
	}

	//lowercase, as `origin` normalizes hosts, so the issuer matches `serviceUrl`
	private static func makeServiceUrl() throws -> URL {
		try URL(string: "https://\(UUID().uuidString.lowercased()).auth.example.com")
			.unwrapped
	}

	//static, so init can build the metadata before every stored property is set
	private static func metadata(issuer issuerUrl: URL) throws -> Data {
		func absoluteUrlString(for endpoint: Endpoint) -> String {
			endpoint.url(issuer: issuerUrl).absoluteString
		}
		let signingAlgs = [
			"RS256", "RS384", "RS512", "PS256", "PS384", "PS512",
			"ES256", "ES256K", "ES384", "ES512",
		]
		return try JSONSerialization.data(withJSONObject: [
			"issuer": issuerUrl.absoluteString,
			"request_parameter_supported": true,
			"request_uri_parameter_supported": true,
			"require_request_uri_registration": true,
			"scopes_supported": [
				"atproto", "transition:email", "transition:generic",
				"transition:chat.bsky",
			],
			"subject_types_supported": ["public"],
			"response_types_supported": ["code"],
			"response_modes_supported": ["query", "fragment", "form_post"],
			"grant_types_supported": ["authorization_code", "refresh_token"],
			"code_challenge_methods_supported": ["S256"],
			"ui_locales_supported": ["en-US"],
			"display_values_supported": ["page", "popup", "touch"],
			"request_object_signing_alg_values_supported": signingAlgs + ["none"],
			"authorization_response_iss_parameter_supported": true,
			"request_object_encryption_alg_values_supported": [],
			"request_object_encryption_enc_values_supported": [],
			"jwks_uri": absoluteUrlString(for: .jwks),
			"authorization_endpoint": absoluteUrlString(for: .authorization),
			"token_endpoint": absoluteUrlString(for: .token),
			"token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
			"token_endpoint_auth_signing_alg_values_supported": signingAlgs,
			"revocation_endpoint": absoluteUrlString(for: .revocation),
			"pushed_authorization_request_endpoint": absoluteUrlString(
				for: .pushedAuthorizationRequest
			),
			"require_pushed_authorization_requests": true,
			"dpop_signing_alg_values_supported": signingAlgs,
			"client_id_metadata_document_supported": true,
			"prompt_values_supported": [
				"none", "login", "consent", "select_account", "create",
			],
		])
	}
}
