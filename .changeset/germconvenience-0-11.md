---
"@germ-network/atprotoclient": patch
---

Require GermConvenience 0.11.0, whose `URLSession.manualRedirect()` also refuses redirects on Linux and Android. The DID resolvers screen the host once, before the request, so they depend on redirects not being followed.
