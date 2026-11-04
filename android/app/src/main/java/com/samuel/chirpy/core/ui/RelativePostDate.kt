package com.samuel.chirpy.core.ui

import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.samuel.chirpy.R
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

@Composable
internal fun rememberRelativePostDateFormatter(): (Instant) -> String {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val now =
        produceState(Instant.now(), lifecycle) {
            lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                while (true) {
                    value = Instant.now()
                    delay(60_000)
                }
            }
        }
    val locale = LocalConfiguration.current.locales[0]
    val formatter =
        remember(locale) { MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.SHORT) }
    val justNow = stringResource(R.string.just_now)
    // One lifecycle observer and timer per feed; state is read only by each date label.
    return remember(now, formatter, justNow) {
        { createdAt ->
            val units = elapsedPostTime(createdAt, now.value, ZoneId.systemDefault())

            if (units.isEmpty()) {
                justNow
            } else {
                formatter.formatMeasures(
                    *units
                        .map { (unit, amount) ->
                            val measureUnit =
                                when (unit) {
                                    ChronoUnit.YEARS -> MeasureUnit.YEAR
                                    ChronoUnit.MONTHS -> MeasureUnit.MONTH
                                    ChronoUnit.DAYS -> MeasureUnit.DAY
                                    ChronoUnit.HOURS -> MeasureUnit.HOUR
                                    else -> MeasureUnit.MINUTE
                                }
                            Measure(amount, measureUnit)
                        }
                        .toTypedArray(),
                )
            }
        }
    }
}

@Composable
internal fun RelativePostDate(
    createdAt: Instant,
    formatDate: (Instant) -> String,
    modifier: Modifier = Modifier,
) {
    Text(
        formatDate(createdAt),
        modifier = modifier,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}
