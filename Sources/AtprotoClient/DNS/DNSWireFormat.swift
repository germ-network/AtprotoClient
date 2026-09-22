//
//  DNSWireFormat.swift
//  AtprotoClient
//

import AtprotoTypes
import Foundation

extension Atproto {
	/// A minimal RFC 1035 wire-format codec, scoped to exactly what a TXT lookup
	/// needs: encode a single-question TXT query, decode the answer section of a
	/// response into the joined character-strings of every TXT record found.
	///
	/// Deliberately not a general DNS message library - no support for other query
	/// types, no EDNS0, no writing responses. Pure byte-in/string-out; no platform
	/// dependency, so it is tested directly against captured wire bytes rather than
	/// through a live resolver.
	public enum DNSWireFormat {
		private static let typeTXT: UInt16 = 16
		private static let classIN: UInt16 = 1

		public enum EncodeError: Error, Equatable, Sendable {
			case emptyLabel
			case labelTooLong(String)
			case nameTooLong
		}

		public enum DecodeError: Error, Equatable, Sendable, CustomStringConvertible {
			case truncated
			/// RCODE 3 - the name does not exist. Distinct from `serverFailure` so a
			/// caller can treat "no record" and "this server misbehaved" differently.
			case nameError
			case serverFailure(rcode: UInt8)
			case compressionPointerLoop
			case malformedLabel

			public var description: String {
				switch self {
				case .truncated: "truncated DNS message"
				case .nameError: "NXDOMAIN"
				case .serverFailure(let rcode): "server failure, RCODE \(rcode)"
				case .compressionPointerLoop: "DNS name compression pointer loop"
				case .malformedLabel: "malformed DNS label"
				}
			}
		}

		/// Encodes a single-question TXT query for `name`.
		///
		/// ID is fixed at 0 (RFC 8484 4.1: DoH responses are not associated with a
		/// query by ID, so a fixed ID improves cache hit rates for intermediaries).
		public static func encodeTXTQuery(name: String) throws -> Data {
			var qname = Data()
			for label in name.split(separator: ".", omittingEmptySubsequences: false) {
				let bytes = Array(label.utf8)
				guard !bytes.isEmpty else { throw EncodeError.emptyLabel }
				guard bytes.count <= 63 else {
					throw EncodeError.labelTooLong(String(label))
				}
				qname.append(UInt8(bytes.count))
				qname.append(contentsOf: bytes)
			}
			qname.append(0)
			guard qname.count <= 255 else { throw EncodeError.nameTooLong }

			var message = Data(capacity: 12 + qname.count + 4)
			message.append(contentsOf: [0x00, 0x00])  // ID = 0
			message.append(contentsOf: [0x01, 0x00])  // flags: RD=1, everything else 0
			message.append(contentsOf: [0x00, 0x01])  // QDCOUNT = 1
			// ANCOUNT / NSCOUNT / ARCOUNT = 0
			message.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
			message.append(qname)
			message.append(contentsOf: beBytes(typeTXT))
			message.append(contentsOf: beBytes(classIN))
			return message
		}

		/// The strings of every TXT record in the answer section, one entry per
		/// record, that record's own character-strings already joined.
		///
		/// Throws `.nameError` for NXDOMAIN - callers that treat "no record" as a
		/// normal outcome (not every consumer does) should catch that case
		/// specifically rather than translating every throw into "try the next
		/// server".
		public static func decodeTXTRecords(_ data: Data) throws -> [String] {
			let bytes = [UInt8](data)
			guard bytes.count >= 12 else { throw DecodeError.truncated }

			let flags = beUInt16(bytes, at: 2)
			let rcode = UInt8(flags & 0x000F)
			guard rcode != 3 else { throw DecodeError.nameError }
			guard rcode == 0 else { throw DecodeError.serverFailure(rcode: rcode) }

			let qdcount = Int(beUInt16(bytes, at: 4))
			let ancount = Int(beUInt16(bytes, at: 6))

			var offset = 12
			for _ in 0..<qdcount {
				offset = try skipName(bytes, at: offset)
				guard offset + 4 <= bytes.count else { throw DecodeError.truncated }
				offset += 4  // QTYPE + QCLASS
			}

			var results: [String] = []
			// ancount is wire-supplied and unvalidated against the message's actual
			// size at this point - reserving it directly would let a malicious
			// 65535-answer header force a large transient allocation before the
			// per-answer bounds checks below ever run.
			results.reserveCapacity(min(ancount, 32))
			for _ in 0..<ancount {
				offset = try skipName(bytes, at: offset)  // owner name, unused
				guard offset + 10 <= bytes.count else {
					throw DecodeError.truncated
				}
				let type = beUInt16(bytes, at: offset)
				let rdlength = Int(beUInt16(bytes, at: offset + 8))
				offset += 10
				guard offset + rdlength <= bytes.count else {
					throw DecodeError.truncated
				}
				if type == typeTXT {
					results.append(
						joinedCharacterStrings(
							bytes[offset..<offset + rdlength]))
				}
				offset += rdlength
			}
			return results
		}

		/// Advances past a (possibly compressed) name, returning the offset just
		/// past it - past the pointer if compressed, since a pointer always
		/// terminates the name in the message being read.
		private static func skipName(_ bytes: [UInt8], at start: Int) throws -> Int {
			var offset = start
			var next: Int?
			var jumps = 0

			while true {
				guard offset < bytes.count else { throw DecodeError.truncated }
				let length = bytes[offset]

				if length == 0 {
					if next == nil { next = offset + 1 }
					return next!
				} else if length & 0xC0 == 0xC0 {
					guard offset + 1 < bytes.count else {
						throw DecodeError.truncated
					}
					let pointer =
						(Int(length & 0x3F) << 8) | Int(bytes[offset + 1])
					if next == nil { next = offset + 2 }
					jumps += 1
					// a pointer must target strictly earlier in the message - this
					// alone guarantees termination; the jump cap is defense in depth.
					guard pointer < offset, jumps <= 128 else {
						throw DecodeError.compressionPointerLoop
					}
					offset = pointer
				} else if length & 0xC0 != 0 {
					throw DecodeError.malformedLabel
				} else {
					offset += 1 + Int(length)
					guard offset <= bytes.count else {
						throw DecodeError.truncated
					}
				}
			}
		}

		/// TXT RDATA is one or more length-prefixed character-strings; join them,
		/// matching what a resolver client library's own `TXTRecord` accessor does
		/// for the common single-string case.
		private static func joinedCharacterStrings(_ rdata: ArraySlice<UInt8>) -> String {
			var strings: [String] = []
			var i = rdata.startIndex
			while i < rdata.endIndex {
				let length = Int(rdata[i])
				i += 1
				let end = min(i + length, rdata.endIndex)
				strings.append(String(decoding: rdata[i..<end], as: UTF8.self))
				i = end
			}
			return strings.joined()
		}

		private static func beBytes(_ value: UInt16) -> [UInt8] {
			[UInt8(value >> 8), UInt8(value & 0xFF)]
		}

		private static func beUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
			(UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
		}
	}
}
