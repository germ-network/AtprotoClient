---
"@germ-network/atprotoclient": minor
---

Add DNS-over-HTTPS TXT and well-known atproto-did handle-resolution components: `Atproto.WellKnownHandleResolver` and `Atproto.DnsHandleResolver`, plus the underlying `Atproto.DNSWireFormat` codec, `Atproto.DNSTXTFetcher` protocol, and `Atproto.DoHTXTFetcher` conformer they're built on. Together these implement the two handle-resolution methods from the atproto handle spec (https://atproto.com/specs/handle) - the DNS TXT method and the HTTPS well-known method - as standalone, portable, `Sendable` components matching `DidWebResolver`/`DidPlcResolver`'s conventions: redirect refusal, response-size bounds, and the resolved value parsed as an `Atproto.DID` (method form checked via `Atproto.DID.init(string:)`).
