# @germ-network/atprotoclient

## 0.5.5

### Patch Changes

- [#27](https://github.com/germ-network/AtprotoClient/pull/27) [`73a7b06`](https://github.com/germ-network/AtprotoClient/commit/73a7b06881dabb046ce23b6363b971a69c387c81) Thanks [@germ-mark](https://github.com/germ-mark)! - \* Expand ProfileRecordDetailed to include all primitive fields
  - adjust the profile record API's so that we can get an unauth request, and the full auth response object

## 0.5.4

### Patch Changes

- [#25](https://github.com/germ-network/AtprotoClient/pull/25) [`3482ed2`](https://github.com/germ-network/AtprotoClient/commit/3482ed2b582ab04d146bb457dfb1b819cae80d4f) Thanks [@germ-mark](https://github.com/germ-mark)! - We must verify the handle we get back in a DiDDocument

  Following the [AtprotoTypes changes](https://github.com/germ-network/AtprotoTypes/pull/34), we

  - define a shared method to make a call, check for not found error code(s), and return an optional (we use this for `resolveHandle`, but also for `getBlob` and `getRecord`
  - Adjust the `Resolver` interface slightly to return the `Atproto.DiDDocument.Verified` struct instead of a tuple
  - add default implementations to check the resolved DIDDocument for handle validity and did equality

## 0.5.3

### Patch Changes

- [#23](https://github.com/germ-network/AtprotoClient/pull/23) [`068804e`](https://github.com/germ-network/AtprotoClient/commit/068804e891f39175d60d6239570e4d4313348694) Thanks [@germ-mark](https://github.com/germ-mark)! - adopt AtprotoTypes renaming and separate out a mocks target

## 0.5.2

### Patch Changes

- [#21](https://github.com/germ-network/AtprotoClient/pull/21) [`18c1967`](https://github.com/germ-network/AtprotoClient/commit/18c19675cb2ed08a2b85e5cb66e32014842ea3f7) Thanks [@anna-germ](https://github.com/anna-germ)! - Update createdAt record properties to use Atproto.Datetime

## 0.5.1

### Patch Changes

- [#18](https://github.com/germ-network/AtprotoClient/pull/18) [`5d7ad8d`](https://github.com/germ-network/AtprotoClient/commit/5d7ad8d00b68b3d3e9a5d90a647e9517830f3f74) Thanks [@germ-mark](https://github.com/germ-mark)! - add deleteRecord handling, and directly return an error HTTPResponse instead of throwing, catching ,and returning the error response

- [#18](https://github.com/germ-network/AtprotoClient/pull/18) [`7f049c2`](https://github.com/germ-network/AtprotoClient/commit/7f049c211e0150317d53be0ad5f283cfbf300edd) Thanks [@germ-mark](https://github.com/germ-mark)! - implement mock deleteRecord

## 0.5.0

### Minor Changes

- [#15](https://github.com/germ-network/AtprotoClient/pull/15) [`6e21716`](https://github.com/germ-network/AtprotoClient/commit/6e21716e7f15cc5266b6d3c48edb1b4c79219a28) Thanks [@germ-mark](https://github.com/germ-mark)! - Change the PDS to store untyped, encoded records so it can store record types it's not aware of. Validating records is out of scope of this mock. Changes the response API to take an optional authed' DID, which the caller can infer from parsing auth parameters

## 0.4.0

### Minor Changes

- [#14](https://github.com/germ-network/AtprotoClient/pull/14) [`6fe6a0f`](https://github.com/germ-network/AtprotoClient/commit/6fe6a0fabe65ee58609591137b5e40d18764bdef) Thanks [@germ-mark](https://github.com/germ-mark)! - Remove default parameter of URLSession.shared

## 0.3.0

### Minor Changes

- [#12](https://github.com/germ-network/AtprotoClient/pull/12) [`b214d36`](https://github.com/germ-network/AtprotoClient/commit/b214d36420be584a53812fa79cf5a91d502fcc68) Thanks [@germ-mark](https://github.com/germ-mark)! - Build a MockPDS around the AtprotoMockAgent, renamed to MockRepo
  Also constrain the default Agent url construction to enforce that /xrpc/ is the top-level
  path, per the spec

## 0.2.0

### Minor Changes

- [#8](https://github.com/germ-network/AtprotoClient/pull/8) [`cf060e2`](https://github.com/germ-network/AtprotoClient/commit/cf060e286436445d58c0d1ad9308ba3db055d36e) Thanks [@anna-germ](https://github.com/anna-germ)! - Move authed calls from XRPCCallable to XRPCAuthCallable

- [#8](https://github.com/germ-network/AtprotoClient/pull/8) [`6f18fe7`](https://github.com/germ-network/AtprotoClient/commit/6f18fe7e9a5ec5522fd26bd0ef5e68b1bf03c147) Thanks [@anna-germ](https://github.com/anna-germ)! - Refactor protocol names to be in line with Swift API guidance

### Patch Changes

- [#10](https://github.com/germ-network/AtprotoClient/pull/10) [`d7ff2b0`](https://github.com/germ-network/AtprotoClient/commit/d7ff2b07bf603fe0f23c2f1a713eded85dc04ef6) Thanks [@germ-mark](https://github.com/germ-mark)! - Add convenience API's to automatically fill in repo and literal:self rkeys

- [#8](https://github.com/germ-network/AtprotoClient/pull/8) [`a144218`](https://github.com/germ-network/AtprotoClient/commit/a144218f330609b8c5ca231d49ecc0f68b5c72ae) Thanks [@anna-germ](https://github.com/anna-germ)! - Move Bluesky lexicons to AtprotoLexiconBsky

- [#8](https://github.com/germ-network/AtprotoClient/pull/8) [`9868f44`](https://github.com/germ-network/AtprotoClient/commit/9868f44b34e736f004bc0c780bfacf166627724d) Thanks [@anna-germ](https://github.com/anna-germ)! - Create AuthPDSAgent to combine multiple relevant protocols

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
