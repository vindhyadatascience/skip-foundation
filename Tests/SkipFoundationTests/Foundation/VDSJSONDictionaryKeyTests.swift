// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

final class VDSJSONDictionaryKeyTests: XCTestCase {
    private func expectFailure(_ message: String, operation: () throws -> Void) {
        do { try operation() } catch { return }
        XCTFail(message)
    }

    func testRawAndErasedStringKeysSerializeThroughBothWriterOrders() throws {
        let raw: [String: Int] = ["z": 2, "a": 1]
        let erased: [AnyHashable: Int] = [("z" as AnyHashable): 2, ("a" as AnyHashable): 1]
        let objects: [Any] = [raw, erased]
        let formats: [JSONSerialization.WritingOptions] = [[], [.sortedKeys], [.sortedKeys, .prettyPrinted]]
        for object in objects {
            XCTAssertTrue(JSONSerialization.isValidJSONObject(object))
            for format in formats {
                let data = try JSONSerialization.data(withJSONObject: object, options: format)
                XCTAssertEqual(try JSONDecoder().decode([String: Int].self, from: data), raw)
            }
            let sorted = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            XCTAssertEqual(String(data: sorted, encoding: .utf8), #"{"a":1,"z":2}"#)
        }
    }

    func testRawAndErasedNonStringKeysAreRejected() {
        let raw: [Int: Int] = [1: 2]
        let erased: [AnyHashable: Int] = [(1 as AnyHashable): 2]
        let objects: [Any] = [raw, erased]
        for object in objects {
            XCTAssertFalse(JSONSerialization.isValidJSONObject(object))
            // Apple documents invalid objects as a programming-error exception,
            // not a Swift Error: the portable refusal API is isValidJSONObject.
            // https://developer.apple.com/documentation/foundation/jsonserialization/data(withjsonobject:options:)
            // The fork additionally guarantees a catchable refusal at the writer.
            #if SKIP
            expectFailure("Unsorted JSON must refuse non-string keys") {
                _ = try JSONSerialization.data(withJSONObject: object)
            }
            expectFailure("Sorted JSON must refuse non-string keys") {
                _ = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            }
            #endif
        }
    }

    func testNestedStringKeysAreAcceptedAndNestedNonStringKeysAreRejected() throws {
        let nested: [String: Any] = ["raw": ["a": 1], "erased": [("b" as AnyHashable): 2]]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(nested))
        let data = try JSONSerialization.data(withJSONObject: nested, options: [.sortedKeys])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"erased":{"b":2},"raw":{"a":1}}"#)
        let invalid: [String: Any] = ["nested": [(1 as AnyHashable): 2]]
        XCTAssertFalse(JSONSerialization.isValidJSONObject(invalid))
        #if SKIP
        expectFailure("Nested non-string JSON keys must fail") {
            _ = try JSONSerialization.data(withJSONObject: invalid, options: [.sortedKeys])
        }
        #endif
    }
}
