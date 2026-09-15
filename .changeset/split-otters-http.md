---
"@germ-network/atprotoclient": patch
---

Fix build against GermConvenience 0.8.0, which split `HTTPDataResponse` and
`HTTPFetcher` out of the base `GermConvenience` library into a new
`GermConvenienceHTTP` product. Adds the `GermConvenienceHTTP` product
dependency and the matching import everywhere those types are used, and
raises the floor to `from: "0.8.0"`.

No public API change — this only restores buildability against current
GermConvenience releases.
