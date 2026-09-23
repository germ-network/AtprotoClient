//
//  DNSFixtures.swift
//  AtprotoClientTests
//

import Foundation

/// Minimal RFC 1035 response builders for tests that need a full DoH response
/// body, not just the question `DNSWireFormat.encodeTXTQuery` produces. Kept
/// separate from `DNSWireFormatTests`' own handcrafted cases so
/// `DoHTXTFetcherTests` and future conformer tests share one builder rather
/// than three copies of the same byte-packing.
enum DNSFixtures {
	static func name(_ dotted: String) -> [UInt8] {
		var out: [UInt8] = []
		for label in dotted.split(separator: ".") {
			out.append(UInt8(label.utf8.count))
			out.append(contentsOf: Array(label.utf8))
		}
		out.append(0)
		return out
	}

	private static func beU16(_ value: UInt16) -> [UInt8] {
		[UInt8(value >> 8), UInt8(value & 0xFF)]
	}

	/// A response with RCODE=0 and one TXT answer containing `text` as a single
	/// character-string.
	static func txtResponse(question: String, text: String) -> Data {
		var bytes: [UInt8] = [0, 0, 0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0]
		bytes += name(question)
		bytes += [0, 16, 0, 1]
		bytes += [0xC0, 0x0C]  // owner name: pointer back to the question
		bytes += [0, 16, 0, 1, 0, 0, 0, 60]
		let stringBytes = Array(text.utf8)
		let rdata: [UInt8] = [UInt8(stringBytes.count)] + stringBytes
		bytes += beU16(UInt16(rdata.count))
		bytes += rdata
		return Data(bytes)
	}

	/// A response with RCODE=3 (NXDOMAIN), no answers - a real "no record"
	/// outcome, as opposed to a transport/server failure.
	static func nxdomainResponse(question: String) -> Data {
		var bytes: [UInt8] = [0, 0, 0x81, 0x83, 0, 1, 0, 0, 0, 0, 0, 0]
		bytes += name(question)
		bytes += [0, 16, 0, 1]
		return Data(bytes)
	}
}
