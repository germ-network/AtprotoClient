---
"@germ-network/atprotoclient": minor
---

Add `AuthCallable.putRecord(_:validate:swapCommit:swap:)` taking an `Atproto.RecordSwap?`, so a record can be written only if none exists (`.absent` sends `swapRecord: null`) or only over a specific CID. Requires the AtprotoTypes release that adds `RecordSwap`.
