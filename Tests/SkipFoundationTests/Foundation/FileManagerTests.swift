// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
import Foundation
import XCTest

@available(macOS 11, iOS 14, watchOS 7, tvOS 14, *)
final class FileManagerTests: XCTestCase {
    func testFileManager() throws {
        let tmp = NSTemporaryDirectory()
        //logger.log("temporary folder: \(tmp)")
        XCTAssertNotNil(tmp)
        XCTAssertNotEqual("", tmp)

        let fm = FileManager.default
        XCTAssertNotNil(fm)

        XCTAssertEqual("NSFileAppendOnly", FileAttributeKey.appendOnly.rawValue)
        XCTAssertEqual("NSFileCreationDate", FileAttributeKey.creationDate.rawValue)
        XCTAssertEqual("NSFileDeviceIdentifier", FileAttributeKey.deviceIdentifier.rawValue)
        XCTAssertEqual("NSFileExtensionHidden", FileAttributeKey.extensionHidden.rawValue)
        XCTAssertEqual("NSFileGroupOwnerAccountID", FileAttributeKey.groupOwnerAccountID.rawValue)
        XCTAssertEqual("NSFileGroupOwnerAccountName", FileAttributeKey.groupOwnerAccountName.rawValue)
        XCTAssertEqual("NSFileHFSCreatorCode", FileAttributeKey.hfsCreatorCode.rawValue)
        XCTAssertEqual("NSFileHFSTypeCode", FileAttributeKey.hfsTypeCode.rawValue)
        XCTAssertEqual("NSFileImmutable", FileAttributeKey.immutable.rawValue)
        XCTAssertEqual("NSFileModificationDate", FileAttributeKey.modificationDate.rawValue)
        XCTAssertEqual("NSFileOwnerAccountID", FileAttributeKey.ownerAccountID.rawValue)
        XCTAssertEqual("NSFileOwnerAccountName", FileAttributeKey.ownerAccountName.rawValue)
        XCTAssertEqual("NSFilePosixPermissions", FileAttributeKey.posixPermissions.rawValue)
        XCTAssertEqual("NSFileProtectionKey", FileAttributeKey.protectionKey.rawValue)
        XCTAssertEqual("NSFileReferenceCount", FileAttributeKey.referenceCount.rawValue)
        XCTAssertEqual("NSFileSystemFileNumber", FileAttributeKey.systemFileNumber.rawValue)
        XCTAssertEqual("NSFileSystemFreeNodes", FileAttributeKey.systemFreeNodes.rawValue)
        XCTAssertEqual("NSFileSystemFreeSize", FileAttributeKey.systemFreeSize.rawValue)
        XCTAssertEqual("NSFileSystemNodes", FileAttributeKey.systemNodes.rawValue)
        XCTAssertEqual("NSFileSystemNumber", FileAttributeKey.systemNumber.rawValue)
        XCTAssertEqual("NSFileSystemSize", FileAttributeKey.systemSize.rawValue)
        XCTAssertEqual("NSFileType", FileAttributeKey.type.rawValue)
        XCTAssertEqual("NSFileBusy", FileAttributeKey.busy.rawValue)

    }

    func testDocumentsDirectory() throws {
        let url = try FileManager.default.url(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
        #if !SKIP
        XCTAssertEqual("Documents", url.lastPathComponent)
        #else
        // Robolectric:  /var/folders/zl/wkdjv4s1271fbm6w0plzknkh0000gn/T/robolectric-FileManagerTests_testFileLocations_SkipFoundation_debugUnitTest525656974178778848/skip.foundation.test-dataDir/files/
        // Emulator: /data/user/0/skip.foundation.test/files/
        XCTAssertEqual("files", url.lastPathComponent)
        #endif
    }

    func testCachesDirectory() throws {
        let url = try FileManager.default.url(for: FileManager.SearchPathDirectory.cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
        #if !SKIP
        XCTAssertEqual("Caches", url.lastPathComponent)
        #else
        // Emulator: /data/user/0/skip.foundation.test/cache/
        XCTAssertEqual("cache", url.lastPathComponent)
        #endif
    }
    // VDS fork (vds.1): modificationDate must be the last-modified time, not the creation time.
    // A future date is used because macOS moves a file's birth time back to an earlier mtime, which
    // would make the creation time equal the set date and hide the bug.
    func testModificationDateIsLastModifiedTime() throws {
        let fm = FileManager.default
        let path = NSTemporaryDirectory() + "vds-mtime-\(UUID().uuidString).txt"
        defer { try? fm.removeItem(atPath: path) }
        XCTAssertTrue(fm.createFile(atPath: path, contents: "first".data(using: .utf8), attributes: nil))
        let created = try XCTUnwrap(try fm.attributesOfItem(atPath: path)[FileAttributeKey.creationDate] as? Date)

        let later = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 86_400.0 * 30.0).rounded())
        try "second, longer".write(toFile: path, atomically: false, encoding: .utf8)
        try fm.setAttributes([FileAttributeKey.modificationDate: later], ofItemAtPath: path)

        let attrs = try fm.attributesOfItem(atPath: path)
        let modified = try XCTUnwrap(attrs[FileAttributeKey.modificationDate] as? Date)
        XCTAssertEqual(modified.timeIntervalSince1970, later.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertGreaterThan(modified.timeIntervalSince1970 - created.timeIntervalSince1970, 86_400.0)
    }

    // VDS fork (vds.1): the size reads as Int64 on both platforms (NSNumber on Apple, Long on Skip).
    func testFileSizeReadsAsInt64() throws {
        let fm = FileManager.default
        let path = NSTemporaryDirectory() + "vds-size-\(UUID().uuidString).bin"
        defer { try? fm.removeItem(atPath: path) }
        XCTAssertTrue(fm.createFile(atPath: path, contents: "seven!!".data(using: .utf8), attributes: nil))
        let attrs = try fm.attributesOfItem(atPath: path)
        XCTAssertEqual(attrs[FileAttributeKey.size] as? Int64, Int64(7))
    }
}
