---
"@germ-network/atprotoclient": patch
---

`Relationships` now decodes and encodes `blockingByList` under the lexicon's key. It used `blockingbyList`, so the viewer's own list blocks never decoded.
