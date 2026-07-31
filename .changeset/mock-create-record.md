---
"@germ-network/atprotoclient": minor
---

Serve `com.atproto.repo.createRecord` from MockPDS. Same guards and body handling as `putRecord`, but the PDS mints the record key — a TID, so the key callers recover from `uri` parses as one — instead of taking it from the input. Production paths that create records (blocking, for one) were previously untestable against the mock: it 400'd on the way in.
