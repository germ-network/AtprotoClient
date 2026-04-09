---
"@germ-network/atprotoclient": minor
---

Change the PDS to store untyped, encoded records so it can store record types it's not aware of. Validating records is out of scope of this mock. Changes the response API to take an optional authed' DID, which the caller can infer from parsing auth parameters
