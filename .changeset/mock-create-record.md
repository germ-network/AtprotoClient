---
"@germ-network/atprotoclient": minor
---

Serve `com.atproto.repo.createRecord` from MockPDS. Same guards and body handling as `putRecord`, but the PDS mints the record key — a TID, so the key callers recover from `uri` parses as one. A caller-supplied `rkey` is refused with a 400 rather than honored: without the already-exists failure modeled too, honoring it would just be `putRecord` under another name. Production paths that create records (blocking, for one) were previously untestable against the mock: it 400'd on the way in.

Fixes the record `uri` the mock reports. Reads returned `at://did:web:example.com/NSID(rawValue: "app.bsky.graph.block")/<rkey>` — a hardcoded authority, and `collection` interpolated as a struct rather than its `rawValue` — and `putRecord` returned the bare placeholder `"example.com"`. Every uri is now built in one place from the repo's own DID, so create, put and read all name the same record the same way.

Fixes the `cid` that `createRecord` and `putRecord` return: it was the literal `"mock"`, which does not parse as a CID (no `b` prefix, not base32), so feeding it back to anything that takes one failed at the boundary. It is now `Atproto.CID.mock().string`, matching what reads already returned.

Raises the GermConvenience floor to 0.3.0 and aligns the mock's errors with its cleaned-up handling. The mock's generic 400s said `"Invalid Request"` — with a space, matching no atproto error name — so `parse` fell through and every one reached the caller as an opaque `.unrecognized(400 )`. They are `InvalidRequest` now, which is in `defaultErrors`, so consumers get a typed `.xrpcError` they can match on. `getRecord`'s `catch` moved off `HTTPResponseError.unsuccessfulString`, which 0.3.0 no longer throws, onto the type plus its `code` / `bodyString` accessors.

Breaking: `MockRepo.init` takes the repo's `did`. Callers that construct a `MockRepo` directly need updating; `MockPDS.host(did:bskyProfile:)` is unchanged. Anything asserting on the old `uri` or `cid` values, or matching a mock 400 as `.unrecognized`, needs updating too.

The GermConvenience floor is the one to watch downstream: SwiftPM's `from:` is `upToNextMajor` on 0.x, so this drags a consumer's whole graph onto 0.3.0, which is source-breaking for anything that mutates a `BundledHTTPRequest`. oauth4swift ≥ 0.6.0 carries its companion change; first-party mutation sites migrate to `settingHeader(_:for:)`.
