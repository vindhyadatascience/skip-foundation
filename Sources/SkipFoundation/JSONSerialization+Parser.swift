// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP

internal class JSONParser {
    private let parser: VDSJSONStreamParser

    init(data: Data) {
        parser = VDSJSONStreamParser(data.platformValue)
    }

    init(bytes: [UInt8]) {
        parser = VDSJSONStreamParser(Data(bytes).platformValue)
    }

    public func parseJSONValue() throws -> JSONValue { return try parser.parseJSONValue() }
    public func parseSwiftValue(exactNumbers: Bool = false) throws -> Any { return try parser.parseSwiftValue(exactNumbers) }
}

/// Mimics the constructor `UInt8(ascii:)`
func UByte(ascii: String) -> UInt8 {
    ascii.first().toByte().toUByte()
}

/// Mimics the constructor `UInt8(ascii:)`
func UInt8(ascii: String) -> UInt8 {
    ascii.first().toByte().toUByte()
}

internal let UInt8_space: UInt8 = UInt8(ascii: " ")
internal let UInt8_return: UInt8 = UInt8(ascii: "\r")
internal let UInt8_newline: UInt8 = UInt8(ascii: "\n")
internal let UInt8_tab: UInt8 = UInt8(ascii: "\t")

internal let UInt8_colon: UInt8 = UInt8(ascii: ":")
internal let UInt8_comma: UInt8 = UInt8(ascii: ",")

internal let UInt8_openbrace: UInt8 = UInt8(ascii: "{")
internal let UInt8_closebrace: UInt8 = UInt8(ascii: "}")

internal let UInt8_openbracket: UInt8 = UInt8(ascii: "[")
internal let UInt8_closebracket: UInt8 = UInt8(ascii: "]")

internal let UInt8_quote: UInt8 = UInt8(ascii: "\"")
internal let UInt8_backslash: UInt8 = UInt8(ascii: "\\")

internal let UInt8Array_true: Array<UInt8> = [UInt8(ascii: "t"), UInt8(ascii: "r"), UInt8(ascii: "u"), UInt8(ascii: "e")]
internal let UInt8Array_false: Array<UInt8> = [UInt8(ascii: "f"), UInt8(ascii: "a"), UInt8(ascii: "l"), UInt8(ascii: "s"), UInt8(ascii: "e")]
internal let UInt8Array_null: Array<UInt8> = [UInt8(ascii: "n"), UInt8(ascii: "u"), UInt8(ascii: "l"), UInt8(ascii: "l")]

enum JSONError: Error, Equatable {
    case cannotConvertInputDataToUTF8
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(characterIndex: Int)
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, in: String, index: Int)
    case unescapedControlCharacterInString(ascii: UInt8, in: String, index: Int)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: String, index: Int)
    case couldNotCreateUnicodeScalarFromUInt32(in: String, index: Int, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(index: Int)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed
    case invalidUTF8Sequence(Data, characterIndex: Int)
}

#endif
