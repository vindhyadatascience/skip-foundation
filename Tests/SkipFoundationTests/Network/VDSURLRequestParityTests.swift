// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

/// RNABrowser-fiea.11: these hermetic API assertions run against native Foundation
/// and transpiled SkipFoundation. No request is sent; transport policy is separate.
final class VDSURLRequestParityTests: XCTestCase {
    private let url = URL(string: "https://example.invalid/reference")!

    private func matchingKeys(_ request: URLRequest, field: String) -> [String] {
        var keys: [String] = []
        for (key, _) in request.allHTTPHeaderFields ?? [String: String]() {
            if key.lowercased() == field.lowercased() { keys.append(key) }
        }
        return keys
    }

    func testReservedHeaderNamesAreStoredAndMutatedInEveryCase() {
        let names = ["Content-Length", "Authorization", "Connection", "Host",
                     "Proxy-Authenticate", "Proxy-Authorization", "WWW-Authenticate"]
        for name in names {
            for spelling in [name, name.lowercased(), name.uppercased()] {
                var request = URLRequest(url: url)
                request.setValue("unrelated, exactly", forHTTPHeaderField: "X-Unrelated")
                request.setValue("first", forHTTPHeaderField: spelling)
                XCTAssertEqual(request.value(forHTTPHeaderField: name.lowercased()), "first", name)
                XCTAssertEqual(request.value(forHTTPHeaderField: name.uppercased()), "first", name)
                XCTAssertEqual(matchingKeys(request, field: name).count, 1, name)
                request.setValue("replacement", forHTTPHeaderField: name.uppercased())
                XCTAssertEqual(request.value(forHTTPHeaderField: name.lowercased()), "replacement", name)
                XCTAssertEqual(matchingKeys(request, field: name).count, 1, name)
                request.addValue("additional", forHTTPHeaderField: name.lowercased())
                XCTAssertEqual(request.value(forHTTPHeaderField: name.uppercased()), "replacement,additional", name)
                XCTAssertEqual(matchingKeys(request, field: name).count, 1, name)
                request.setValue(nil, forHTTPHeaderField: name)
                XCTAssertNil(request.value(forHTTPHeaderField: name.lowercased()), name)
                XCTAssertNil(request.value(forHTTPHeaderField: name.uppercased()), name)
                XCTAssertTrue(matchingKeys(request, field: name).isEmpty, name)
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-unrelated"), "unrelated, exactly", name)
            }
        }
    }

    func testUnknownHeaderCaseVariantsShareOneValue() {
        var request = URLRequest(url: url)
        request.setValue("one", forHTTPHeaderField: "X-Private-Case")
        request.addValue("two", forHTTPHeaderField: "x-private-case")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-PRIVATE-CASE"), "one,two")
        XCTAssertEqual(matchingKeys(request, field: "x-private-case").count, 1)
        request.setValue("three", forHTTPHeaderField: "X-PRIVATE-CASE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-private-case"), "three")
        XCTAssertEqual(matchingKeys(request, field: "x-private-case").count, 1)
        request.setValue(nil, forHTTPHeaderField: "x-private-case")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-PRIVATE-CASE"))
        XCTAssertTrue(matchingKeys(request, field: "x-private-case").isEmpty)
    }

    func testDictionarySeededFieldsUseCaseInsensitiveReplacementAndAppend() {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["x-private-case": "seed", "AUTHORIZATION": "first",
                                       "X-Unrelated": "keep, exactly"]
        request.addValue("next", forHTTPHeaderField: "X-PRIVATE-CASE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-private-case"), "seed,next")
        request.setValue("second", forHTTPHeaderField: "authorization")
        request.addValue("third", forHTTPHeaderField: "Authorization")
        XCTAssertEqual(request.value(forHTTPHeaderField: "AUTHORIZATION"), "second,third")
        XCTAssertEqual(matchingKeys(request, field: "authorization").count, 1)
        XCTAssertEqual(matchingKeys(request, field: "x-private-case").count, 1)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-unrelated"), "keep, exactly")
    }

    func testNilRemovalClearsAllCaseVariantsWithoutTouchingOtherFields() {
        for name in ["X-Private-Case", "Authorization"] {
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [name: "one", name.lowercased(): "two", "X-Unrelated": "keep"]
            request.setValue(nil, forHTTPHeaderField: name.uppercased())
            XCTAssertNil(request.value(forHTTPHeaderField: name))
            XCTAssertTrue(matchingKeys(request, field: name).isEmpty)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-unrelated"), "keep")
        }
    }

    func testHeaderMutationPreservesRequestValuesAndValueCopies() {
        var request = URLRequest(url: url, timeoutInterval: 17.0)
        request.httpMethod = "POST"
        request.httpBody = Data("body remains intact".utf8)
        request.setValue("original", forHTTPHeaderField: "X-Private-Case")
        request.setValue("unchanged; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let original = request
        request.addValue("next", forHTTPHeaderField: "x-private-case")
        request.setValue("replacement", forHTTPHeaderField: "X-PRIVATE-CASE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-private-case"), "replacement")
        XCTAssertEqual(original.value(forHTTPHeaderField: "x-private-case"), "original")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "unchanged; charset=utf-8")
        XCTAssertEqual(request.url, original.url)
        XCTAssertEqual(request.httpMethod, original.httpMethod)
        XCTAssertEqual(request.httpBody, original.httpBody)
        XCTAssertEqual(request.timeoutInterval, original.timeoutInterval)
    }

    func testEmptyAppendsKeepNativeCommaSeparators() {
        let cases: [(String, String, String)] = [
            ("one", "", "one,"),
            ("", "two", ",two"),
            ("", "", ","),
        ]
        for (initial, appended, expected) in cases {
            var request = URLRequest(url: url)
            request.setValue("keep", forHTTPHeaderField: "X-Unrelated")
            request.setValue(initial, forHTTPHeaderField: "X-Empty")
            request.addValue(appended, forHTTPHeaderField: "x-empty")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-EMPTY"), expected)
            XCTAssertEqual(matchingKeys(request, field: "x-empty").count, 1)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-unrelated"), "keep")
        }
    }

    func testOPTIONSNormalizationMatchesNativeWithoutChangingOtherMethods() {
        var request = URLRequest(url: url)
        for spelling in ["options", "OpTiOnS", "OPTIONS"] {
            request.httpMethod = spelling
            XCTAssertEqual(request.httpMethod, "OPTIONS")
        }
        let unchanged = ["trace", "TRACE", "PATCH", "custom", "CuStOm"]
        for method in unchanged {
            request.httpMethod = method
            XCTAssertEqual(request.httpMethod, method)
        }
        request.httpMethod = "get"
        XCTAssertEqual(request.httpMethod, "GET")
    }
}
