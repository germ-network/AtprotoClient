//
//  BskyCDNTests.swift
//  AtprotoClientTests
//

import AtprotoTypes
import Foundation
import Testing

@testable import AtprotoClient

@Suite struct BskyCDNTests {
	private func blob(cid: Atproto.CID) -> Atproto.Primitive.Blob {
		.init(ref: .init(link: cid), mimeType: "image/jpeg", size: 100)
	}

	@Test("imageURL builds the exact avatar CDN URL")
	func avatarURLExactString() throws {
		let did = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		let url = try Atproto.BskyCDN.imageURL(.avatar, did: did, blob: blob(cid: cid))

		#expect(
			url.absoluteString
				== "https://cdn.bsky.app/img/avatar/plain/\(did.rawValue)/\(cid.string)@jpeg"
		)
	}

	@Test("imageURL builds the exact banner CDN URL against a custom host")
	func bannerURLExactString() throws {
		let did = Atproto.DID(method: .web, identifier: "example.com")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		let url = try Atproto.BskyCDN.imageURL(
			.banner, did: did, blob: blob(cid: cid),
			host: URL(string: "https://cdn.example.net")!)

		#expect(
			url.absoluteString
				== "https://cdn.example.net/img/banner/plain/\(did.rawValue)/\(cid.string)@jpeg"
		)
	}

	@Test("A crafted DID with path-traversal segments can't escape the CDN path")
	func pathTraversalDIDStaysOneSegment() throws {
		let did = try Atproto.DID(string: "did:plc:../../../../evil/x?y#z")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		let url = try Atproto.BskyCDN.imageURL(.avatar, did: did, blob: blob(cid: cid))

		#expect(url.host == "cdn.bsky.app")
		#expect(url.absoluteString.hasPrefix("https://cdn.bsky.app/img/avatar/plain/"))
		// The DID's own "/" characters must be encoded, not literal path
		// separators - otherwise the ".." segments could traverse out of
		// /img/avatar/plain/.
		#expect(!url.absoluteString.contains("/.."))
		#expect(url.absoluteString.contains("%2F"))
	}

	@Test(
		"A trailing slash and an uppercase scheme are both accepted, producing the canonical URL",
		arguments: ["https://cdn.bsky.app/", "HTTPS://cdn.bsky.app"]
	)
	func acceptsTrailingSlashAndUppercaseScheme(_ hostString: String) throws {
		let did = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		let url = try Atproto.BskyCDN.imageURL(
			.avatar, did: did, blob: blob(cid: cid),
			host: URL(string: hostString)!)

		#expect(
			url.absoluteString
				== "https://cdn.bsky.app/img/avatar/plain/\(did.rawValue)/\(cid.string)@jpeg"
		)
	}

	@Test("An '@' in a DID is percent-encoded, leaving only the '@jpeg' suffix literal")
	func atSignInDIDIsEncoded() throws {
		let did = Atproto.DID(method: .plc, identifier: "evil@example.com")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		let url = try Atproto.BskyCDN.imageURL(.avatar, did: did, blob: blob(cid: cid))

		#expect(did.rawValue.contains("@"))
		let pathAfterDID = url.absoluteString.components(separatedBy: "/").last ?? ""
		#expect(pathAfterDID == "\(cid.string)@jpeg")
		#expect(url.absoluteString.contains("%40"))
	}

	@Test(
		"imageURL rejects a host that isn't a bare http(s) origin",
		arguments: [
			"https://cdn.bsky.app/extra",
			"https://cdn.bsky.app?x=1",
			"https://cdn.bsky.app#frag",
			"https://user@cdn.bsky.app",
			"ftp://cdn.bsky.app",
		]
	)
	func rejectsNonBareHost(_ hostString: String) throws {
		let did = Atproto.DID(method: .plc, identifier: "aaaaaaaaaaaaaaaaaaaaaaaa")
		let cid = try Atproto.CID(string: "baaaaaaaa")

		#expect(throws: Atproto.BskyCDN.Errors.invalidHost) {
			try Atproto.BskyCDN.imageURL(
				.avatar, did: did, blob: blob(cid: cid),
				host: URL(string: hostString)!)
		}
	}
}
