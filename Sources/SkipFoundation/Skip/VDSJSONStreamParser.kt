// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
package skip.foundation

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import skip.lib.Array
import skip.lib.Dictionary

/** Parse the original packed UTF-8 bytes directly into the requested tree.
 * No boxed byte array, complete input String, or intermediate org.json tree.
 * Container storage is mutable while parsing and handed to Skip exactly once.
 */
internal class VDSJSONStreamParser(private val bytes: ByteArray) {
    private var index = 0

    private var exactNumbers = false
    fun parseSwiftValue(exactNumbers: Boolean = false): Any {
        this.exactNumbers = exactNumbers
        return parseRoot(false)
    }
    fun parseJSONValue(): JSONValue = parseRoot(true) as JSONValue

    private fun parseRoot(jsonValue: Boolean): Any {
        if (bytes.size >= 3 && bytes[0] == 0xef.toByte() && bytes[1] == 0xbb.toByte() && bytes[2] == 0xbf.toByte()) index = 3
        val result = value(jsonValue, 0)
        whitespace()
        if (index != bytes.size) invalid()
        return result
    }

    private fun whitespace() {
        while (index < bytes.size && (bytes[index] == 0x20.toByte() || bytes[index] == 0x09.toByte() || bytes[index] == 0x0a.toByte() || bytes[index] == 0x0d.toByte())) index++
    }

    private fun invalid(): Nothing {
        if (index >= bytes.size) throw JSONError.unexpectedEndOfFile
        throw JSONError.unexpectedCharacter(ascii = bytes[index].toUByte(), characterIndex = index)
    }

    private fun take(c: Char): Boolean {
        if (index < bytes.size && bytes[index].toInt() == c.code) { index++; return true }
        return false
    }

    // Foundation accepts one trailing comma in both arrays and objects.
    // Leave the closing delimiter for the caller; repeated commas still fail.
    private fun more(close: Char): Boolean {
        if (!take(',')) return false
        whitespace()
        return index >= bytes.size || bytes[index].toInt() != close.code
    }

    private fun require(c: Char) { if (!take(c)) invalid() }

    private fun value(jsonValue: Boolean, depth: Int): Any {
        whitespace()
        if (index >= bytes.size) invalid()
        return when (bytes[index].toInt().toChar()) {
            '{' -> {
                if (depth >= 512) throw JSONError.tooManyNestedArraysOrDictionaries(characterIndex = index)
                index++
                whitespace()
                if (jsonValue) {
                    val entries = LinkedHashMap<String, JSONValue>()
                    if (!take('}')) {
                        do {
                            whitespace(); val key = string(); whitespace(); require(':')
                            entries[key] = value(true, depth + 1) as JSONValue
                            whitespace()
                        } while (more('}'))
                        require('}')
                    }
                    JSONValue.object_(Dictionary(entries, nocopy = true))
                } else {
                    val entries = LinkedHashMap<String, Any>()
                    if (!take('}')) {
                        do {
                            whitespace(); val key = string(); whitespace(); require(':')
                            entries[key] = value(false, depth + 1)
                            whitespace()
                        } while (more('}'))
                        require('}')
                    }
                    Dictionary(entries, nocopy = true)
                }
            }
            '[' -> {
                if (depth >= 512) throw JSONError.tooManyNestedArraysOrDictionaries(characterIndex = index)
                index++
                whitespace()
                if (jsonValue) {
                    val elements = ArrayList<JSONValue>()
                    if (!take(']')) {
                        do { elements.add(value(true, depth + 1) as JSONValue); whitespace() } while (more(']'))
                        require(']')
                    }
                    JSONValue.array(Array(elements, nocopy = true))
                } else {
                    val elements = ArrayList<Any>()
                    if (!take(']')) {
                        do { elements.add(value(false, depth + 1)); whitespace() } while (more(']'))
                        require(']')
                    }
                    Array(elements, nocopy = true)
                }
            }
            '"' -> string().let { if (jsonValue) JSONValue.string(it) else it }
            't' -> { literal("true"); if (jsonValue) JSONValue.bool(true) else true }
            'f' -> { literal("false"); if (jsonValue) JSONValue.bool(false) else false }
            'n' -> { literal("null"); if (jsonValue) JSONValue.null_ else NSNull.null_ }
            '-', in '0'..'9' -> {
                val text = number()
                if (jsonValue) JSONValue.number(text) else {
                    // Preserve exact signed integers, as JSONTokener did, before
                    // falling back to the floating point representation.
                    val signed = text.toLongOrNull()
                    if (text.startsWith("-") && java.math.BigDecimal(text).signum() == 0) {
                        -0.0
                    } else if (signed != null) {
                        if (signed >= Int.MIN_VALUE && signed <= Int.MAX_VALUE) signed.toInt() else signed
                    } else try {
                        if (exactNumbers || (!text.contains('.') && !text.contains('e') && !text.contains('E'))) {
                            java.math.BigDecimal(text)
                        } else {
                            text.toDoubleOrNull()?.takeIf { it.isFinite() }
                                ?: throw JSONError.numberIsNotRepresentableInSwift(parsed = text)
                        }
                    } catch (_: NumberFormatException) {
                        throw JSONError.numberIsNotRepresentableInSwift(parsed = text)
                    }
                }
            }
            else -> invalid()
        }
    }

    private fun literal(text: String) {
        for (c in text) require(c)
    }

    private fun digit(): Boolean = index < bytes.size && bytes[index] >= 48.toByte() && bytes[index] <= 57.toByte()

    private fun number(): String {
        val start = index
        take('-')
        if (!take('0')) {
            if (!digit() || bytes[index] == 48.toByte()) invalid()
            while (digit()) index++
        }
        if (take('.')) {
            if (!digit()) invalid()
            while (digit()) index++
        }
        if (take('e') || take('E')) {
            if (!take('+')) take('-')
            if (!digit()) invalid()
            while (digit()) index++
        }
        return String(bytes, start, index - start, Charsets.US_ASCII)
    }

    private fun utf8(start: Int, end: Int): String = try {
        Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes, start, end - start)).toString()
    } catch (_: java.nio.charset.CharacterCodingException) {
        throw JSONError.invalidUTF8Sequence(Data(platformValue = bytes), characterIndex = start)
    }

    private fun hex(): Int {
        var result = 0
        repeat(4) {
            if (index >= bytes.size) invalid()
            val c = bytes[index++].toInt().toChar()
            val digit = c.digitToIntOrNull(16) ?: invalid()
            result = result * 16 + digit
        }
        return result
    }

    private fun string(): String {
        require('"')
        var start = index
        var builder: StringBuilder? = null
        while (index < bytes.size) {
            val byte = bytes[index].toInt() and 0xff
            if (byte < 0x20) invalid()
            if (byte == '"'.code) {
                val tail = utf8(start, index++)
                return builder?.append(tail)?.toString() ?: tail
            }
            if (byte == '\\'.code) {
                val output = builder ?: StringBuilder().also { builder = it }
                output.append(utf8(start, index))
                index++
                if (index >= bytes.size) invalid()
                when (bytes[index++].toInt().toChar()) {
                    '"' -> output.append('"')
                    '\\' -> output.append('\\')
                    '/' -> output.append('/')
                    'b' -> output.append('\b')
                    'f' -> output.append('\u000c')
                    'n' -> output.append('\n')
                    'r' -> output.append('\r')
                    't' -> output.append('\t')
                    'u' -> {
                        val code = hex()
                        if (code in 0xd800..0xdbff) {
                            require('\\'); require('u')
                            val low = hex()
                            if (low !in 0xdc00..0xdfff) invalid()
                            output.append(code.toChar()).append(low.toChar())
                        } else {
                            if (code in 0xdc00..0xdfff) invalid()
                            output.append(code.toChar())
                        }
                    }
                    else -> invalid()
                }
                start = index
            } else index++
        }
        invalid()
    }
}
