// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

final class VDSStringFormatLocaleTests: XCTestCase {
    func testExplicitLocaleControlsDecimalSeparatorAndNilIsNeutral() {
        XCTAssertEqual(String(format: "%.2f", locale: Locale(identifier: "de_DE"), 1.5), "1,50")
        XCTAssertEqual(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), 1.5), "1.50")
        XCTAssertEqual(String(format: "%.2f", locale: nil, 1.5), "1.50")
        XCTAssertEqual(String(format: "%.2f", locale: Locale(identifier: "de_DE"), arguments: [1.5]), "1,50")
        XCTAssertEqual(String(format: "%2$@ %1$.2f", locale: Locale(identifier: "de_DE"), 1.5, "value"), "value 1,50")
    }
}
