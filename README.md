Defines methods for an [atproto](https://atproto.com) client that make [xrpc](https://atproto.com/specs/xrpc) calls

You make use of this library by providing an implementation of a type conforming to `AtprotoAgent`:
* is sendable
* declares a base serviceUrl
* provides a method with the signature of `HTTPFetcher` (`BundledHTTPRequest) async throws -> HTTPDataResponse`)

This library defines the basic xrpc request and procedure calls for that agent, as well as some more
high-level methods to get and put records and get follows and blocks.

Examples of agents:
* An authenticated agent, where the serviceUrl is the pdsUrl. This agent is capable of proxying requests
* An unauthenticated agent for a specific pds; the serviceUrl is the pdsUrl
* An unauthenticated agent to a public endpoint. We provide an example for `https://public.api.bsky.app`

It is up to the client to understand which agents are capable of which xrpc calls

### Linting and Practices
The repo has a .editorconfig and .swift-format setup. We use both swift
formatter and linter:
```
swift format . -ri && swift format lint . -r
```

We also use the [periphery static analyzer](https://github.com/peripheryapp/periphery) and have a configured `periphery.yml`