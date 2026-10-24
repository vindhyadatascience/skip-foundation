// Copyright 2026 Vindhya Data Science
// SPDX-License-Identifier: MPL-2.0
package skip.foundation

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import skip.lib.Array
import skip.lib.Dictionary

/** Host-JVM allocation checks: exercise the public codec, not a modeled loop.
 * Allocated bytes are deterministic enough to distinguish linear from quadratic
 * copying without a wall-clock deadline. The lead runs these under HotSpot.
 */
@RunWith(AndroidJUnit4::class)
class VDSJSONCodecCostTests {
    private fun allocated(body: () -> Unit): Long {
        val bean = java.lang.management.ManagementFactory.getThreadMXBean()
        check(bean is com.sun.management.ThreadMXBean && bean.isThreadAllocatedMemorySupported)
        if (!bean.isThreadAllocatedMemoryEnabled) bean.isThreadAllocatedMemoryEnabled = true
        val thread = java.lang.Thread.currentThread().id
        val before = bean.getThreadAllocatedBytes(thread)
        body()
        return bean.getThreadAllocatedBytes(thread) - before
    }

    @Test fun encoderAllocationGrowsLinearlyForWideArrays() {
        val small = Array((0 until 2048).toList(), nocopy = true)
        val large = Array((0 until 8192).toList(), nocopy = true)
        repeat(3) { JSONEncoder().encode(small) }
        val smallBytes = (0 until 3).minOf { allocated { JSONEncoder().encode(small) } }
        val largeBytes = (0 until 3).minOf { allocated {
            val data = JSONEncoder().encode(large)
            assertTrue(data.count > 8192)
        } }
        assertTrue("4x input allocated $largeBytes versus $smallBytes", largeBytes < smallBytes * 6)
        assertTrue("allocation budget: $largeBytes", largeBytes < 8192L * 4096)
    }

    @Test fun encoderAllocationGrowsLinearlyForWideObjects() {
        val small = Dictionary((0 until 1024).associate { "key_$it" to it }, nocopy = true)
        val large = Dictionary((0 until 4096).associate { "key_$it" to it }, nocopy = true)
        repeat(3) { JSONEncoder().encode(small) }
        val smallBytes = (0 until 3).minOf { allocated { JSONEncoder().encode(small) } }
        val largeBytes = (0 until 3).minOf { allocated { JSONEncoder().encode(large) } }
        assertTrue("4x keys allocated $largeBytes versus $smallBytes", largeBytes < smallBytes * 6)
        assertTrue("allocation budget: $largeBytes", largeBytes < 4096L * 4096)
    }

    @Test fun decoderAvoidsBoxingEveryInputByte() {
        val text = "[\"" + "x".repeat(524288) + "\"]"
        val input = Data(platformValue = text.toByteArray(Charsets.UTF_8))
        repeat(2) { JSONDecoder().decoder(input) }
        val bytes = (0 until 3).minOf { allocated { JSONDecoder().decoder(input) } }
        // A packed input, bounded string buffer and single decoded string fit
        // below 12 bytes/input byte; a boxed byte-array round trip does not.
        assertTrue("decoder allocated $bytes for ${input.count} bytes", bytes < input.count.toLong() * 12)
    }
}
