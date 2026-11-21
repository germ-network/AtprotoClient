---
"@germ-network/atprotoclient": minor
---

Add `MockAS`, a mock OAuth authorization server, and give `MockPDS` one

`MockPDS()` is now its own authorization server, as a self-hosted PDS is: its protected resource metadata names its own `serviceUrl` as the issuer, and it answers the authorization server metadata and `/oauth/*` endpoints. `MockPDS.withEntryway(_:)` instead puts a PDS behind a separate authorization server host, optionally shared between several PDSes. The authorization server metadata is built from the issuer, so it passes discovery's exact `issuer` match; the previous hard-coded `https://example.com` issuer did not.

`MockAS` answers through a `MockHTTPFetcher` that always serves the metadata. Tests script the other endpoints on `fetcher` and read back what the client sent, using `url(for:)` with `MockAS.Endpoint` to address them. A router that has the raw request can pass it to `response(for:)`, and use `handles(_:)` to decide which requests are for the authorization server.

Other `MockPDS` changes:

- `response(for: BundledHTTPRequest, authedDid:)` accepts a raw request, for routers that already have one, so OAuth requests no longer pass through `XRPCRequestComponents`.
- `recordNotFoundStatus` sets the status a missing record is reported with, since implementations differ: the reference PDS sends 400, tranquil sends 404. The default is 400.
- Paths outside `/xrpc/` that the PDS does not serve now get a plain 404, instead of an `InvalidRequest` 400.
