// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

@available(macOS 13, iOS 16, tvOS 16, watchOS 10, *)
final class VDSLocalizationInterpolationTests: XCTestCase {
    func testLocalizationValueKeepsIntegerAndStringFormatterArguments() {
        let short: Int16 = -7
        let count = 42
        let long: Int64 = 99
        let name = "fox"
        let value: String.LocalizationValue = "VDS integers \(short) \(count) \(long) and \(name)"
        XCTAssertEqual(String(localized: value, table: "VDS-Interop-NoTable", bundle: Bundle.module,
            locale: Locale.current), "VDS integers -7 42 99 and fox")
        let resource = LocalizedStringResource(value, table: "VDS-Interop-NoTable", locale: Locale.current,
            bundle: .atURL(Bundle.module.bundleURL))
        XCTAssertEqual(String(localized: resource), "VDS integers -7 42 99 and fox")
    }

    func testLocalizationValueKeepsFloatingPointFormatterArguments() {
        let double: Double = 1.5
        let float: Float = 2.5
        let value: String.LocalizationValue = "VDS decimals \(double) and \(float)"
        let expected = "VDS decimals " + String(format: "%f", locale: Locale.current, double)
            + " and " + String(format: "%f", locale: Locale.current, float)
        XCTAssertEqual(String(localized: value, table: "VDS-Interop-NoTable", bundle: Bundle.module,
            locale: Locale.current), expected)
    }

    func testDirectResourceInterpolationKeepsRawNumericTypes() {
        let count = 7
        let double = 3.5
        let float: Float = 2.25
        let name = "alpha"
        let resource: LocalizedStringResource = "VDS direct \(count) / \(double) / \(float) / \(name)"
        let expected = "VDS direct 7 / " + String(format: "%f", locale: Locale.current, double)
            + " / " + String(format: "%f", locale: Locale.current, float) + " / alpha"
        XCTAssertEqual(String(localized: resource), expected)
    }

    func testDirectResourceAndExplicitValueRetainTheSameLookupKey() {
        let count = 7
        let double = 3.5
        let name = "alpha"
        let direct: LocalizedStringResource = "VDS key 100% \(count) / \(double) / \(name)"
        let value: String.LocalizationValue = "VDS key 100% \(count) / \(double) / \(name)"
        let explicit = LocalizedStringResource(value)
        XCTAssertEqual(direct.key, explicit.key)
        XCTAssertEqual(String(localized: direct), String(localized: explicit))
    }

    #if SKIP
    func testAttributedLocalizationPassesRawArgumentsThroughMarkdown() throws {
        let count = 7
        let name = "fox"
        let value: String.LocalizationValue = "**\(count)** \(name)"
        let attributed = AttributedString(localized: value, table: "VDS-Interop-NoTable", bundle: Bundle.module,
            locale: Locale.current)
        XCTAssertEqual(attributed.string, "**7** fox")
        let markdown = try XCTUnwrap(attributed.markdownNode)
        let paragraph = try XCTUnwrap(markdown.children?.first())
        let bold = try XCTUnwrap(paragraph.children?.first())
        XCTAssertEqual(bold.children?.first()?.string, "7")
    }
    #endif
}
