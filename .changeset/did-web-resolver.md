---
"@germ-network/atprotoclient": minor
---

Add `Atproto.DidWebResolver`: resolves a did:web identifier to its DID document by fetching `https://{host}/.well-known/did.json`, matching `@atproto/identity`'s reference resolver (Accept header, redirect refusal, single-segment restriction). Screens the resolved host against a strict hostname allowlist before ever fetching, since a did:web identifier is attacker-influenced input turned directly into a URL (Linear GER-1912) — no port, loopback, or IP-literal host is accepted. Defaults to a redirect-refusing session; fetcher injection is reserved for tests.
