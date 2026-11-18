---
"@germ-network/atprotoclient": patch
---

`callExpectingOptional` reads a 404 whose body names one of the endpoint's not-found codes as nil, as it already did for a 400. tranquil PDSes answer a missing record with `404 RecordNotFound`, which surfaced as `.unrecognized(404)`.
