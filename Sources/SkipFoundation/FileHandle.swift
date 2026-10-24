// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
#if SKIP

/// Seekable file I/O with packed byte buffers. Opening a writing/updating handle
/// requires an existing file and never truncates it implicitly.
public class FileHandle {
    private let channel: java.nio.channels.FileChannel

    public init(forReadingFrom url: URL) throws {
        channel = java.nio.channels.FileChannel.open(platformFilePath(for: url), java.nio.file.StandardOpenOption.READ)
    }

    public init(forWritingTo url: URL) throws {
        channel = java.nio.channels.FileChannel.open(platformFilePath(for: url), java.nio.file.StandardOpenOption.WRITE)
    }

    public init(forUpdating url: URL) throws {
        channel = java.nio.channels.FileChannel.open(platformFilePath(for: url), java.nio.file.StandardOpenOption.READ, java.nio.file.StandardOpenOption.WRITE)
    }

    public func read(upToCount count: Int) throws -> Data? {
        if count < 0 { throw java.lang.IllegalArgumentException("Read count must not be negative") }
        // A zero-sized channel read validates openness and read access without
        // advancing the file. Foundation returns nil for a zero-byte request.
        let _ = channel.read(java.nio.ByteBuffer.allocate(0))
        if count == 0 { return nil }
        let available = max(Int64(0), channel.size() - channel.position())
        if available == Int64(0) { return nil }
        let capacity = Int(min(Int64(count), available))
        let buffer = java.nio.ByteBuffer.allocate(capacity)
        let size = channel.read(buffer)
        if size < 0 { return nil }
        return Data(platformValue: buffer.array().copyOf(size))
    }

    public func readToEnd() throws -> Data? {
        let output = java.io.ByteArrayOutputStream()
        while let chunk = try read(upToCount: 8192) {
            if chunk.isEmpty { break }
            output.write(chunk.platformValue)
        }
        return output.size() == 0 ? nil : Data(platformValue: output.toByteArray())
    }

    public func write(contentsOf data: Data) throws {
        let buffer = java.nio.ByteBuffer.wrap(data.platformValue)
        // An empty write still checks the handle and its access mode.
        if !buffer.hasRemaining() { let _ = channel.write(buffer) }
        while buffer.hasRemaining() {
            if channel.write(buffer) == 0 { throw java.io.IOException("File write made no progress") }
        }
    }

    public func offset() throws -> UInt64 { return UInt64(channel.position()) }

    private func checkedOffset(_ offset: UInt64) throws -> Int64 {
        if offset > UInt64(Int64.max) { throw java.io.IOException("File offset exceeds the platform range") }
        return Int64(offset)
    }

    public func seek(toOffset offset: UInt64) throws {
        channel.position(try checkedOffset(offset))
    }

    public func seekToEnd() throws -> UInt64 {
        let size = channel.size()
        channel.position(size)
        return UInt64(size)
    }

    public func truncate(atOffset offset: UInt64) throws {
        let length = try checkedOffset(offset)
        if length > channel.size() {
            // FileChannel.truncate never extends. One positioned zero byte gives
            // the same zero-filled extension as Foundation, without a giant buffer.
            let zero = java.nio.ByteBuffer.allocate(1)
            let written = channel.write(zero, length - 1)
            if written != 1 { throw java.io.IOException("File extension made no progress") }
        } else {
            channel.truncate(length)
        }
        channel.position(length)
    }

    public func synchronize() throws { channel.force(true) }
    public func close() throws { channel.close() }
}
#endif
