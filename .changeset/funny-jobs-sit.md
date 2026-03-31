---
"@germ-network/atprotoclient": minor
---

Based on further consideration of the client, we are able to omit the client (which wraps an agent) and build the API entirely around the Agent

A type conforming to `AtprotoAgent`

- is sendable
- declares a base serviceURL
- provides a method with the signature of HTTPFetcher (`BundledHTTPRequest) async throws -> HTTPDataResponse`)

We first define primitive xrpc request and procedure methods on AtprotoAgent

We use the primitives to build some basic API's (`getRecord`, `listRecords`, `getBlob`, `putRecord`), as well as a paginated `getFollowsStream` that produces a stream of follows.

A (expected to be authenticated) agent can declare itself capable of proxying, for which we define additional methods that specify the proxying header.

We remove the notion of authenticated request. An agent implementation may be authenticated or unauthenticated and adds the authentication on all requests if it is authenticated.
