// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
package skip.foundation

/** Write UTF-8 directly into the packed output, escaping only JSON syntax. */
internal fun appendJSONQuotedString(output: java.io.ByteArrayOutputStream, value: String, escapeSlashes: Boolean) {
    output.write('"'.code)
    var start = 0
    for (index in value.indices) {
        val c = value[index]
        val escaped = when (c) {
            '"' -> "\\\""
            '\\' -> "\\\\"
            '/' -> if (escapeSlashes) "\\/" else null
            '\b' -> "\\b"
            '\u000c' -> "\\f"
            '\n' -> "\\n"
            '\r' -> "\\r"
            '\t' -> "\\t"
            else -> if (c.code < 0x20) "\\u00" + "0123456789abcdef"[c.code / 16] + "0123456789abcdef"[c.code % 16] else null
        }
        if (escaped != null) {
            if (start < index) output.write(value.substring(start, index).toByteArray(Charsets.UTF_8))
            output.write(escaped.toByteArray(Charsets.US_ASCII))
            start = index + 1
        }
    }
    if (start < value.length) output.write(value.substring(start).toByteArray(Charsets.UTF_8))
    output.write('"'.code)
}
