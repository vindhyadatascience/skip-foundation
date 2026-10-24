// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

final class VDSJSONCodecTests: XCTestCase {
    private func expectFailure(_ message: String, operation: () throws -> Void) {
        do { try operation() } catch { return }
        XCTFail(message)
    }

    struct Payload: Codable, Equatable {
        var values: [Int]
        var labels: [String: String]
        var optional: String?
    }

    func testWideContainersRoundTripWithoutChangingOutputOptions() throws {
        var values = [Int]()
        var labels = [String: String]()
        for index in 0..<4096 { values.append(index); labels["key_\(index)"] = "value_\(index)" }
        let expected = Payload(values: values, labels: labels, optional: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(expected)
        let decoded = try JSONDecoder().decode(Payload.self, from: data)
        XCTAssertEqual(decoded, expected)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("\n"))
        XCTAssertTrue(text.contains("key_4095"))
    }

    func testUnicodeEscapesNullBooleansAndExactSignedIntegers() throws {
        let data = Data(#"{"text":"\uD83C\uDFB5\u0000é漢字","values":[-9223372036854775808,9223372036854775807],"flag":true,"missing":null}"#.utf8)
        let decoded = try JSONDecoder().decode(VDSJSONFields.self, from: data)
        XCTAssertEqual(decoded.text, "🎵\0é漢字")
        XCTAssertEqual(decoded.values, [Int64.min, Int64.max])
        XCTAssertTrue(decoded.flag)
        XCTAssertNil(decoded.missing)
    }

    func testTrailingCommaArraysAndObjectsMatchNativeFoundation() throws {
        let array = Data("[1,2,]".utf8)
        XCTAssertEqual(try JSONDecoder().decode([Int].self, from: array), [1, 2])
        XCTAssertEqual(try JSONSerialization.jsonObject(with: array) as? [Int], [1, 2])
        let object = Data(#"{"key":1,}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode([String: Int].self, from: object), ["key": 1])
        XCTAssertEqual(try JSONSerialization.jsonObject(with: object) as? [String: Int], ["key": 1])
    }

    func testNegativeZeroNumericSignIsRetained() throws {
        for text in ["-0", "-0.0", "-0e5"] {
            let number = try JSONDecoder().decode(Double.self, from: Data(text.utf8))
            XCTAssertEqual(number, 0.0)
            XCTAssertEqual(1.0 / number, -Double.infinity)
        }
    }

    func testMalformedAndTrailingDataAreRefused() {
        for text in ["[1,,2]", "[01]", "[1e]", "[true] false", "{\"x\":1} trailing", "[\"line\nfeed\"]"] {
            expectFailure(text) { _ = try JSONSerialization.jsonObject(with: Data(text.utf8)) }
        }
    }

    func testIntegerBoundsFractionalValuesAndStringTypesRefuseLoss() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(UInt64.self, from: Data("18446744073709551615".utf8)), UInt64.max)
        XCTAssertEqual(try decoder.decode(Int64.self, from: Data("9007199254740993".utf8)), Int64(9007199254740993))
        expectFailure("Int8 overflow must fail") { _ = try decoder.decode(Int8.self, from: Data("128".utf8)) }
        expectFailure("UInt64 overflow must fail") { _ = try decoder.decode(UInt64.self, from: Data("18446744073709551616".utf8)) }
        expectFailure("UInt8 must reject negative values") { _ = try decoder.decode(UInt8.self, from: Data("-1".utf8)) }
        expectFailure("Int must reject fractions") { _ = try decoder.decode(Int.self, from: Data("1.5".utf8)) }
        expectFailure("Double overflow must fail") { _ = try decoder.decode(Double.self, from: Data("1e400".utf8)) }
        expectFailure("Huge integer exponents must fail") { _ = try decoder.decode(Int64.self, from: Data("1e1000000".utf8)) }
        expectFailure("String must reject numeric JSON") { _ = try decoder.decode(String.self, from: Data("123".utf8)) }
        expectFailure("Bool must reject numeric JSON") { _ = try decoder.decode(Bool.self, from: Data("1".utf8)) }
    }

    func testEscapedStringsRoundTripThroughBothCodecs() throws {
        let text = "🎵\0é漢字\n\r\t\u{08}\u{0c}\"\\/"
        let data = try JSONEncoder().encode([text])
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), [text])
        let serialized = try JSONSerialization.data(withJSONObject: ["text": text])
        let decoded = try JSONSerialization.jsonObject(with: serialized) as? [String: String]
        XCTAssertEqual(decoded?["text"], text)
    }

    func testNonFiniteStrategiesRemainExplicit() throws {
        let encoder = JSONEncoder()
        expectFailure("Non-finite encoding must require an explicit strategy") { _ = try encoder.encode([Double.infinity]) }
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "plus", negativeInfinity: "minus", nan: "missing")
        let data = try encoder.encode([Double.infinity, -Double.infinity, Double.nan])
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), ["plus", "minus", "missing"])
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "plus", negativeInfinity: "minus", nan: "missing")
        let values = try decoder.decode([Double].self, from: data)
        XCTAssertEqual(values[0], Double.infinity)
        XCTAssertEqual(values[1], -Double.infinity)
        XCTAssertTrue(values[2].isNaN)
    }

    func testDepthMalformedUnicodeAndDecoderErrorKind() throws {
        let shallow = String(repeating: "[", count: 128) + "0" + String(repeating: "]", count: 128)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: Data(shallow.utf8)))
        let deep = String(repeating: "[", count: 1024) + "0" + String(repeating: "]", count: 1024)
        expectFailure("Over-depth JSON must fail") { _ = try JSONSerialization.jsonObject(with: Data(deep.utf8)) }
        let invalidUTF8 = Data([UInt8(91), UInt8(34), UInt8(0xff), UInt8(34), UInt8(93)])
        expectFailure("Malformed UTF8 must fail") { _ = try JSONSerialization.jsonObject(with: invalidUTF8) }
        do {
            let _ = try JSONDecoder().decode([Int].self, from: Data("[1,,2]".utf8))
            XCTFail("Malformed JSON must fail")
        } catch DecodingError.dataCorrupted { } catch { XCTFail("Expected dataCorrupted, received \(error)") }
    }

    func testNullAndRangeErrorKindsMatchFoundation() {
        do {
            let _ = try JSONDecoder().decode(Int8.self, from: Data("128".utf8))
            XCTFail("Overflow must fail")
        } catch DecodingError.dataCorrupted { } catch { XCTFail("Expected numeric dataCorrupted, received \(error)") }
        do {
            let _ = try JSONDecoder().decode(String.self, from: Data("null".utf8))
            XCTFail("Required String must reject null")
        } catch DecodingError.valueNotFound { } catch { XCTFail("Expected valueNotFound, received \(error)") }
        do {
            let _ = try JSONDecoder().decode(Bool.self, from: Data("1".utf8))
            XCTFail("Bool must reject a number")
        } catch DecodingError.typeMismatch { } catch { XCTFail("Expected typeMismatch, received \(error)") }
    }

    func testFragmentsAndUTF16Input() throws {
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(#""fragment""#.utf8)), "fragment")
        XCTAssertEqual(try JSONDecoder().decode(Bool.self, from: Data("true".utf8)), true)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: Data("true".utf8), options: .fragmentsAllowed) as? Bool, true)
        XCTAssertTrue(try JSONSerialization.jsonObject(with: Data("null".utf8), options: .fragmentsAllowed) is NSNull)
        let utf16 = "[1,2,3]".data(using: .utf16)!
        let decoded = try JSONSerialization.jsonObject(with: utf16) as? [Int]
        XCTAssertEqual(decoded, [1, 2, 3])
        XCTAssertEqual(try JSONDecoder().decode([Int].self, from: utf16), [1, 2, 3])
    }
}

struct VDSJSONFields: Decodable {
    var text: String
    var values: [Int64]
    var flag: Bool
    var missing: String?
}
