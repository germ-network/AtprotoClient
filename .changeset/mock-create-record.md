---
"@germ-network/atprotoclient": minor
---

Serve `com.atproto.repo.createRecord` from MockPDS. Same guards and body handling as `putRecord`, but the PDS mints the record key — a TID, so the key callers recover from `uri` parses as one. A caller-supplied `rkey` is refused with a 400 rather than honored: without the already-exists failure modeled too, honoring it would just be `putRecord` under another name. Production paths that create records (blocking, for one) were previously untestable against the mock: it 400'd on the way in.

Also fixes the record `uri` the mock reports on reads, which was `at://did:web:example.com/NSID(rawValue: "app.bsky.graph.block")/<rkey>` — a hardcoded authority, and `collection` interpolated as a struct rather than its `rawValue`. Every uri is now built in one place from the repo's own DID, so create and read agree.

Breaking: `MockRepo.init` takes the repo's `did`. Callers that construct a `MockRepo` directly need updating; `MockPDS.host(did:bskyProfile:)` is unchanged.
