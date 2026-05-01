---
"@germ-network/atprotoclient": patch
---

We must verify the handle we get back in a DiDDocument

Following the [AtprotoTypes changes](https://github.com/germ-network/AtprotoTypes/pull/34), we
* define a shared method to make a call, check for not found error code(s), and return an optional (we use this for `resolveHandle`, but also for `getBlob` and `getRecord`
* Adjust the `Resolver` interface slightly to return the `Atproto.DiDDocument.Verified` struct instead of a tuple
* add default implementations to check the resolved DIDDocument for handle validity and did equality