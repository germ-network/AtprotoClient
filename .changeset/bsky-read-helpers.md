---
"@germ-network/atprotoclient": minor
---

Add three Bluesky read helpers on `Atproto.XRPC.BskyAppCallable`: `relationshipLookup(actor:others:)`, which reports which `app.bsky.graph.getRelationships` subjects the AppView returned a relationship for and which it didn't (unlike `getRelationships(actor:subjects:)`, which drops every not-found subject and loses which ones they were) - note that this isn't an account-existence check, since the AppView returns a relationship entry for any well-formed DID whether or not the account exists; and `bskyProfileIfExists(actor:)`, which maps `app.bsky.actor.getProfile`'s undeclared not-found shape (a 400 `InvalidRequest` whose message is "Profile not found") to `nil` rather than throwing. Also add `Atproto.BskyCDN.imageURL(_:did:blob:host:)` to build Bluesky CDN image URLs from a blob reference.

Also fix `Lexicon.App.Bsky.Graph.GetRelationships.Parameters.init` to accept exactly 30 `others`, matching the lexicon's `others.maxLength: 30` - it previously rejected exactly 30, and make `Lexicon.App.Bsky.Graph.GetRelationships.Errors` (`tooManyOthersInput`, `actorMismatch`) public - it's already thrown by public API.
