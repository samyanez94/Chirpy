package com.samuel.chirpy.core.ui

import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

// Calendar units preserve real month lengths and local daylight-saving transitions.
internal fun elapsedPostTime(
    createdAt: Instant,
    now: Instant,
    zone: ZoneId,
): List<Pair<ChronoUnit, Long>> {
    if (createdAt >= now) return emptyList()
    var cursor = createdAt.atZone(zone)
    val end = now.atZone(zone)
    val result = mutableListOf<Pair<ChronoUnit, Long>>()
    for (
    unit in
    listOf(
        ChronoUnit.YEARS,
        ChronoUnit.MONTHS,
        ChronoUnit.DAYS,
        ChronoUnit.HOURS,
        ChronoUnit.MINUTES,
    )
    ) {
        val amount = unit.between(cursor, end)
        if (amount > 0) {
            result.add(unit to amount)
            cursor = cursor.plus(amount, unit)
            if (result.size == 2) break
        }
    }
    return result
}
