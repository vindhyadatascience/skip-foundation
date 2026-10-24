// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

/// The same API checks run against Apple Foundation and SkipFoundation.
final class VDSFileStreamingTests: XCTestCase {
    private func expectFailure(_ message: String, operation: () throws -> Void) {
        do { try operation() } catch { return }
        XCTFail(message)
    }

    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("abcdef".utf8).write(to: url)
        return url
    }

    func testSearchPathPluralMatchesSingularForSupportedUserDirectories() throws {
        let directories: [FileManager.SearchPathDirectory] = [.documentDirectory, .cachesDirectory, .applicationSupportDirectory]
        for directory in directories {
            let urls = FileManager.default.urls(for: directory, in: .userDomainMask)
            XCTAssertEqual(urls.count, 1)
            let single = try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false)
            XCTAssertEqual(urls.first?.standardizedFileURL, single.standardizedFileURL)
            XCTAssertTrue(single.isFileURL)
        }
        XCTAssertTrue(FileManager.default.urls(for: .cachesDirectory, in: []).isEmpty)
    }

    func testReadSeekZeroAndEOF() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 2), Data("ab".utf8))
        XCTAssertEqual(try handle.offset(), UInt64(2))
        XCTAssertNil(try handle.read(upToCount: 0))
        XCTAssertEqual(try handle.offset(), UInt64(2))
        try handle.seek(toOffset: 4)
        XCTAssertEqual(try handle.read(upToCount: Int.max), Data("ef".utf8))
        XCTAssertNil(try handle.read(upToCount: 1))
        try handle.seek(toOffset: 100)
        XCTAssertNil(try handle.readToEnd())
        XCTAssertEqual(try handle.offset(), UInt64(100))
    }

    func testWritingDoesNotTruncateAndUpdatingCanReadBack() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try FileHandle(forWritingTo: url)
        try writer.seek(toOffset: 2)
        try writer.write(contentsOf: Data("XY".utf8))
        try writer.synchronize()
        try writer.close()
        XCTAssertEqual(try Data(contentsOf: url), Data("abXYef".utf8))
        let updater = try FileHandle(forUpdating: url)
        defer { try? updater.close() }
        XCTAssertEqual(try updater.seekToEnd(), UInt64(6))
        try updater.write(contentsOf: Data("!".utf8))
        try updater.seek(toOffset: 2)
        XCTAssertEqual(try updater.read(upToCount: 3), Data("XYe".utf8))
    }

    func testTruncateShrinksAndExtendsWithZeroesAndMovesOffset() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 2)
        XCTAssertEqual(try handle.offset(), UInt64(2))
        try handle.truncate(atOffset: 5)
        XCTAssertEqual(try handle.offset(), UInt64(5))
        try handle.seek(toOffset: 0)
        XCTAssertEqual(try handle.readToEnd(), Data([UInt8(97), UInt8(98), UInt8(0), UInt8(0), UInt8(0)]))
    }

    func testClosedAndWrongAccessHandlesFailAndMissingWriteDoesNotCreate() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let reader = try FileHandle(forReadingFrom: url)
        expectFailure("A read-only handle must reject writing") { try reader.write(contentsOf: Data("x".utf8)) }
        try reader.close()
        try reader.close()
        expectFailure("A closed handle must reject reading") { _ = try reader.read(upToCount: 1) }
        expectFailure("A closed handle must reject seeking") { try reader.seek(toOffset: 0) }
        let missing = url.appendingPathExtension("missing")
        expectFailure("A write handle must not create a missing file") { _ = try FileHandle(forWritingTo: missing) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testChunkedReadPreservesPackedBytesAcrossBufferBoundary() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        var bytes = [UInt8]()
        for index in 0..<20003 { bytes.append(UInt8(index % 251)) }
        let expected = Data(bytes)
        try expected.write(to: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.readToEnd(), expected)
    }
}
