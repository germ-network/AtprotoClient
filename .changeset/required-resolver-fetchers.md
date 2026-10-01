---
"@germ-network/atprotoclient": minor
---

Remove the `URLSession` defaults so non-Apple platforms can depend on the fetcher-based API without reaching `URLSession`.

Breaking: `DidWebResolver.init(fetcher:)`, `DidPlcResolver.init(directory:fetcher:)` and `WellKnownHandleResolver.init(fetcher:)` no longer default to a `URLSession.manualRedirect()`-backed fetcher, and now take an `any RedirectRefusingHTTPFetcher` (from GermConvenience 0.14.0, now required), so a redirect-following fetcher no longer compiles. Pass `ManualRedirectFetcher()` from `GermConvenienceURLSession`, or any conformer of your own. `DnsHandleResolver.init(txtFetcher:)` no longer defaults either; pass a `DNSTXTFetcher`, e.g. `DoHTXTFetcher(fetcher:)`. `StubHTTPFetcher` now conforms to `RedirectRefusingHTTPFetcher`. Also drops the unused `FoundationNetworking` imports from the four resolver files.
