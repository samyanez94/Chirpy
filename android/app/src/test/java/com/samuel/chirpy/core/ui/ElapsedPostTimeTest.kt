package com.samuel.chirpy.core.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

class ElapsedPostTimeTest {
    private val zone = ZoneId.of("UTC")

    @Test
    fun calendarMonthsMatchTheFeedExample() {
        assertEquals(
            listOf(ChronoUnit.MONTHS to 2L, ChronoUnit.DAYS to 4L),
            elapsedPostTime(
                Instant.parse("2026-08-31T18:42:00Z"),
                Instant.parse("2026-11-04T21:37:00Z"),
                zone,
            ),
        )
    }

    @Test
    fun recentPostUsesHoursAndMinutes() {
        val now = Instant.parse("2026-11-04T21:37:00Z")
        assertEquals(
            listOf(ChronoUnit.HOURS to 1L, ChronoUnit.MINUTES to 15L),
            elapsedPostTime(now.minusSeconds(4500), now, zone),
        )
    }

    @Test
    fun futureAndSubMinuteDatesUseJustNow() {
        val now = Instant.parse("2026-11-04T21:37:00Z")
        assertEquals(
            emptyList<Pair<ChronoUnit, Long>>(),
            elapsedPostTime(now.plusSeconds(30), now, zone),
        )
        assertEquals(
            emptyList<Pair<ChronoUnit, Long>>(),
            elapsedPostTime(now.minusSeconds(30), now, zone),
        )
    }
}
