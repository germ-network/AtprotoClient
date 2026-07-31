---
"@germ-network/atprotoclient": minor
---

Serve `com.atproto.repo.createRecord` from MockPDS. Same guards and body handling as `putRecord`, but the PDS mints the record key — a TID, so the key callers recover from `uri` parses as one. A caller-supplied `rkey` is refused with a 400 rather than honored: without the already-exists failure modeled too, honoring it would just be `putRecord` under another name. Production paths that create records (blocking, for one) were previously untestable against the mock: it 400'd on the way in.

Fixes the record `uri` the mock reports. Reads returned `at://did:web:example.com/NSID(rawValue: "app.bsky.graph.block")/<rkey>` — a hardcoded authority, and `collection` interpolated as a struct rather than its `rawValue` — and `putRecord` returned the bare placeholder `"example.com"`. Every uri is now built in one place from the repo's own DID, so create, put and read all name the same record the same way.

Fixes the `cid` that `createRecord` and `putRecord` return: it was the literal `"mock"`, which does not parse as a CID (no `b` prefix, not base32), so feeding it back to anything that takes one failed at the boundary. It is now `Atproto.CID.mock().string`, matching what reads already returned.

Breaking: `MockRepo.init` takes the repo's `did`. Callers that construct a `MockRepo` directly need updating; `MockPDS.host(did:bskyProfile:)` is unchanged. Anything asserting on the old `uri` or `cid` values needs updating too.
