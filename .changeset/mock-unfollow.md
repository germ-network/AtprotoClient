---
"@germ-network/atprotoclient": minor
---

Add `unfollow(did:)` to the mock repo and `unfollow(did:from:)` to MockPDS — the inverse of `follow`, removing the matching follow record. Lets tests construct a "not followed" social-graph state (the anchor-route silence-and-relay case). MockAtmosphere parity is added in AtprotoOAuth.
