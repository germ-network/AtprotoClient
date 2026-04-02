# @germ-network/atprotoclient

## 0.1.0

### Minor Changes

- [#3](https://github.com/germ-network/AtprotoClient/pull/3) [`df17b4d`](https://github.com/germ-network/AtprotoClient/commit/df17b4d0298e76d952ea9eb00ced85db1fd01dca) Thanks [@germ-mark](https://github.com/germ-mark)! - Adopt GermConvenience that uses [swift http types](https://github.com/apple/swift-http-types)

  Of note, the new HTTPResponse, unlike URLResponse, no longer contains the request url.

- [#4](https://github.com/germ-network/AtprotoClient/pull/4) [`c71059b`](https://github.com/germ-network/AtprotoClient/commit/c71059b773404e2a506923df6760dc032db9a1c1) Thanks [@germ-mark](https://github.com/germ-mark)! - Based on further consideration of the client, we are able to omit the client (which wraps an agent) and build the API entirely around the Agent

  A type conforming to `AtprotoAgent`

  - is sendable
  - declares a base serviceURL
  - provides a method with the signature of [HTTPFetcher](https://github.com/germ-network/GermConvenience/blob/main/Sources/GermConvenience/HTTPFetcher.swift#L19)

  We first define primitive xrpc request and procedure methods on AtprotoAgent

  We use the primitives to build some basic API's (`getRecord`, `listRecords`, `getBlob`, `putRecord`), as well as a paginated `getFollowsStream` that produces a stream of follows.

  A (expected to be authenticated) agent can declare itself capable of proxying, for which we define additional methods that specify the proxying header.

  We remove the notion of authenticated request. An agent implementation may be authenticated or unauthenticated and adds the authentication on all requests if it is authenticated.

- [#5](https://github.com/germ-network/AtprotoClient/pull/5) [`4332985`](https://github.com/germ-network/AtprotoClient/commit/43329852b35b3cdea446aa2dab5e7437c4a0fb2b) Thanks [@germ-mark](https://github.com/germ-mark)! - narrow xrpc response parsing for
  - the error codes defined in the api spec
  - the error values defined in lexicon
  - the error schema defined for atproto xrpc (https://atproto.com/specs/xrpc#error-responses)
