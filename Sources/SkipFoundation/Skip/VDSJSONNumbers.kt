// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
package skip.foundation

private fun jsonDecimal(value: Number): java.math.BigDecimal? = try {
    if (value is java.math.BigDecimal) value else java.math.BigDecimal(value.toString())
} catch (_: NumberFormatException) { null }

private fun jsonSigned(value: Number, minimum: Long, maximum: Long): Long? {
    val decimal = jsonDecimal(value) ?: return null
    // Compare before expanding an exponent into an integer. A hostile 1e1000000
    // must fail its range check without allocating a million-digit BigInteger.
    if (decimal < java.math.BigDecimal.valueOf(minimum) || decimal > java.math.BigDecimal.valueOf(maximum)) return null
    return try { decimal.longValueExact() } catch (_: ArithmeticException) { null }
}

private fun jsonUnsigned(value: Number, maximum: ULong): ULong? {
    val decimal = jsonDecimal(value) ?: return null
    if (decimal.signum() < 0 || decimal > java.math.BigDecimal(maximum.toString())) return null
    return try { decimal.toBigIntegerExact().toString().toULongOrNull() } catch (_: ArithmeticException) { null }
}

internal fun jsonExactInt(value: Number): Int? = jsonSigned(value, Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong())?.toInt()
internal fun jsonExactInt8(value: Number): Byte? = jsonSigned(value, Byte.MIN_VALUE.toLong(), Byte.MAX_VALUE.toLong())?.toByte()
internal fun jsonExactInt16(value: Number): Short? = jsonSigned(value, Short.MIN_VALUE.toLong(), Short.MAX_VALUE.toLong())?.toShort()
internal fun jsonExactInt32(value: Number): Int? = jsonExactInt(value)
internal fun jsonExactInt64(value: Number): Long? = jsonSigned(value, Long.MIN_VALUE, Long.MAX_VALUE)
internal fun jsonExactUInt(value: Number): UInt? = jsonUnsigned(value, UInt.MAX_VALUE.toULong())?.toUInt()
internal fun jsonExactUInt8(value: Number): UByte? = jsonUnsigned(value, UByte.MAX_VALUE.toULong())?.toUByte()
internal fun jsonExactUInt16(value: Number): UShort? = jsonUnsigned(value, UShort.MAX_VALUE.toULong())?.toUShort()
internal fun jsonExactUInt32(value: Number): UInt? = jsonExactUInt(value)
internal fun jsonExactUInt64(value: Number): ULong? = jsonUnsigned(value, ULong.MAX_VALUE)
internal fun jsonFiniteDouble(value: Number): Double? = value.toDouble().takeIf { it.isFinite() }
internal fun jsonFiniteFloat(value: Number): Float? = value.toFloat().takeIf { it.isFinite() }
