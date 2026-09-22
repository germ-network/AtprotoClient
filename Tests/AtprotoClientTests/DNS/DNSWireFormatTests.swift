//
//  DNSWireFormatTests.swift
//  AtprotoClientTests
//

import Foundation
import Testing

@testable import AtprotoClient

struct DNSWireFormatTests {

	// MARK: - encode

	@Test func encodesTheExpectedQuestionSection() throws {
		let query = try DNSWireFormat.encodeTXTQuery(name: "_atproto.pfrazee.com")

		// captured with `dig`: the byte-for-byte query Cloudflare's DoH endpoint
		// answered to produce `realTXTResponse` below.
		let expected = Data(
			base64Encoded: "AAABAAABAAAAAAAACF9hdHByb3RvB3BmcmF6ZWUDY29tAAAQAAE=")!
		#expect(query == expected)
	}

	@Test func rejectsAnEmptyLabel() {
		#expect(throws: DNSWireFormat.EncodeError.emptyLabel) {
			try DNSWireFormat.encodeTXTQuery(name: "_atproto..example.com")
		}
	}

	@Test func rejectsALabelOver63Bytes() {
		let label = String(repeating: "a", count: 64)
		#expect(throws: DNSWireFormat.EncodeError.labelTooLong(label)) {
			try DNSWireFormat.encodeTXTQuery(name: "\(label).example.com")
		}
	}

	// MARK: - decode: real captured responses

	// `dig +noedns _atproto.pfrazee.com TXT`, captured as the raw RFC 8484
	// response body from Cloudflare's DoH endpoint - a single TXT answer whose
	// owner name is a compression pointer back into the question section.
	static let realTXTResponse = Data(
		base64Encoded:
			"AACBgAABAAEAAAAACF9hdHByb3RvB3BmcmF6ZWUDY29tAAAQAAHADAAQAAEAAAAhACUkZGlkPWRp"
			+ "ZDpwbGM6cmFndGpzbTJqMnZrbndrejN6cDRveHJk"
	)!

	@Test func decodesARealSingleAnswerRecordWithACompressionPointer() throws {
		let records = try DNSWireFormat.decodeTXTRecords(Self.realTXTResponse)
		#expect(records == ["did=did:plc:ragtjsm2j2vknwkz3zp4oxrd"])
	}

	// A real NXDOMAIN response: ANCOUNT=0, NSCOUNT=1 carrying a root-server SOA
	// record in the authority section - the decoder must not mistake that
	// authority record for an answer, and must throw `.nameError`, not silently
	// return an empty array (the fetcher layer is the one that turns that into
	// "no record", not the codec).
	static let realNXDOMAINResponse = Data(
		base64Encoded:
			"AACBgwABAAAAAQAACF9hdHByb3RvKXRoaXMtZGVmaW5pdGVseS1kb2VzLW5vdC1leGlzdC1nZXJt"
			+ "LXByb2JlB2V4YW1wbGUAABAAAQAABgABAAFRgABAAWEMcm9vdC1zZXJ2ZXJzA25ldAAFbnN0bGQM"
			+ "dmVyaXNpZ24tZ3JzA2NvbQB4w4rpAAAHCAAAA4QACTqAAAFRgA=="
	)!

	@Test func nxdomainThrowsNameError() {
		#expect(throws: DNSWireFormat.DecodeError.nameError) {
			try DNSWireFormat.decodeTXTRecords(Self.realNXDOMAINResponse)
		}
	}

	// gmail.com TXT via Cloudflare: 4 real answers, each owner name a
	// compression pointer to the same offset - the multi-answer walk case.
	static let realMultiAnswerResponse = Data(
		base64Encoded:
			"AACBgAABAAQAAAAABWdtYWlsA2NvbQAAEAABwAwAEAABAAAA4gBEQ3lhaG9vLXZlcmlmaWNhdGlv"
			+ "bi1rZXk9K2Vad0lQU2dSeGtBVXpEdHFUOFFoaytqNEExSkY2Vi93dEdveUdUa0VMWT3ADAAQAAEA"
			+ "AADiACAfdj1zcGYxIHJlZGlyZWN0PV9zcGYuZ29vZ2xlLmNvbcAMABAAAQAAAOIAQUBnbG9iYWxz"
			+ "aWduLXNtaW1lLWR2PUNEWVgrWEZIVXcyd21sNi9HYjgrNTlCc0gzMUt6VXI2YzFsMkJQdnFLWDg9"
			+ "wAwAEAABAAAA4gBEQ3lhaG9vLXZlcmlmaWNhdGlvbi1rZXk9ZEtZd2ZWYmF4YXRtY1hpWHk2TERB"
			+ "eE1SaXJxcE9xNXRqOThpSnY5cVdWaz0="
	)!

	@Test func decodesFourAnswersEachAsItsOwnEntry() throws {
		let records = try DNSWireFormat.decodeTXTRecords(Self.realMultiAnswerResponse)
		#expect(records.count == 4)
		#expect(records[1] == "v=spf1 redirect=_spf.google.com")
	}

	// MARK: - decode: handcrafted edge cases

	@Test func joinsMultipleCharacterStringsWithinOneRecord() throws {
		// header (12) + owner "example.com" (13) + TYPE/CLASS/TTL/RDLENGTH (10)
		// + two character-strings totaling 6 bytes of RDATA
		var bytes: [UInt8] = [
			0, 0, 0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0,
		]
		bytes += name("example.com")
		bytes += [0, 16, 0, 1]  // QTYPE=TXT, QCLASS=IN
		bytes += [0xC0, 0x0C]  // answer owner: compression pointer to offset 12
		bytes += [0, 16, 0, 1, 0, 0, 0, 60]  // TYPE, CLASS, TTL
		let rdata: [UInt8] = [3, 0x66, 0x6F, 0x6F, 2, 0x62, 0x61]  // "foo" + "ba"
		bytes += beU16(UInt16(rdata.count))
		bytes += rdata

		let records = try DNSWireFormat.decodeTXTRecords(Data(bytes))
		#expect(records == ["fooba"])
	}

	@Test func skipsAnAnswerThatIsNotTXT() throws {
		var bytes: [UInt8] = [0, 0, 0x81, 0x80, 0, 1, 0, 2, 0, 0, 0, 0]
		bytes += name("example.com")
		bytes += [0, 16, 0, 1]

		// answer 1: an A record, must be skipped
		bytes += [0xC0, 0x0C]
		bytes += [0, 1, 0, 1, 0, 0, 0, 60]
		bytes += beU16(4)
		bytes += [127, 0, 0, 1]

		// answer 2: the real TXT record
		bytes += [0xC0, 0x0C]
		bytes += [0, 16, 0, 1, 0, 0, 0, 60]
		let rdata: [UInt8] = [4] + Array("real".utf8)
		bytes += beU16(UInt16(rdata.count))
		bytes += rdata

		let records = try DNSWireFormat.decodeTXTRecords(Data(bytes))
		#expect(records == ["real"])
	}

	@Test func rejectsAForwardPointingCompressionPointer() {
		// a pointer that targets a later offset than itself must not be
		// followed - it can never terminate the way a well-formed message
		// (where pointers only ever point backward) does.
		var bytes: [UInt8] = [0, 0, 0x81, 0x80, 0, 1, 0, 0, 0, 0, 0, 0]
		let pointerAt = bytes.count
		bytes += [0xC0, UInt8(pointerAt + 4)]  // points past itself
		bytes += [0, 16, 0, 1]

		#expect(throws: DNSWireFormat.DecodeError.compressionPointerLoop) {
			try DNSWireFormat.decodeTXTRecords(Data(bytes))
		}
	}

	@Test func truncatedMessageThrowsRatherThanCrashing() {
		// a header claiming one answer, with nothing after the question
		var bytes: [UInt8] = [0, 0, 0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0]
		bytes += name("example.com")
		bytes += [0, 16, 0, 1]
		// no answer section at all, despite ANCOUNT=1

		#expect(throws: DNSWireFormat.DecodeError.truncated) {
			try DNSWireFormat.decodeTXTRecords(Data(bytes))
		}
	}

	@Test func serverFailureRcodeIsDistinctFromNameError() {
		// RCODE=2, SERVFAIL
		let bytes: [UInt8] = [0, 0, 0x81, 0x82, 0, 0, 0, 0, 0, 0, 0, 0]
		#expect(throws: DNSWireFormat.DecodeError.serverFailure(rcode: 2)) {
			try DNSWireFormat.decodeTXTRecords(Data(bytes))
		}
	}

	// MARK: - helpers

	private func name(_ dotted: String) -> [UInt8] {
		var out: [UInt8] = []
		for label in dotted.split(separator: ".") {
			out.append(UInt8(label.utf8.count))
			out.append(contentsOf: Array(label.utf8))
		}
		out.append(0)
		return out
	}

	private func beU16(_ value: UInt16) -> [UInt8] {
		[UInt8(value >> 8), UInt8(value & 0xFF)]
	}
}
