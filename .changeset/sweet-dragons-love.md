---
"@germ-network/atprotoclient": minor
---

Build a MockPDS around the AtprotoMockAgent, renamed to MockRepo
Also constrain the default Agent url construction to enforce that /xrpc/ is the top-level
path, per the spec