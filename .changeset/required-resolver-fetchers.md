---
"@germ-network/atprotoclient": minor
---

Remove the `URLSession` defaults so non-Apple platforms can depend on the fetcher-based API without reaching `URLSession`.

Breaking: `DidWebResolver.init(fetcher:)`, `DidPlcResolver.init(directory:fetcher:)`, `WellKnownHandleResolver.init(fetcher:)` and `DnsHandleResolver.init(txtFetcher:)` no longer default to a `URLSession.manualRedirect()`-backed fetcher; pass an explicit redirect-refusing `HTTPFetcher` (or `DNSTXTFetcher`). Apple callers can pass `URLSession.manualRedirect()` from `GermConvenienceURLSession` (GermConvenience 0.13.0, now required). Also drops the unused `FoundationNetworking` imports from the four resolver files.
