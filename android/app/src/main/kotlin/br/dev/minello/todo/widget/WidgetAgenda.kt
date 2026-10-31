package br.dev.minello.todo.widget

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/** What the widget draws for one day. */
sealed interface WidgetContent {
  /** The app never wrote anything: no text is available yet. */
  data object AppIcon : WidgetContent

  data class SignedOut(val text: String) : WidgetContent

  /** Nothing due (empty) or the snapshot no longer covers the day (stale). */
  data class Message(val header: String, val text: String) : WidgetContent

  /**
   * [rows] holds today's tasks in the snapshot order, most recent first: the view draws it
   * bottom-up, below the groups. [overdue] and [pending] group what is not listed in [rows]; each
   * is `null` when there is nothing to group.
   */
  data class Tasks(
      val header: String,
      val overdue: String?,
      val pending: String?,
      val rows: List<WidgetRow>,
  ) : WidgetContent
}

data class WidgetRow(val id: String, val title: String)

/**
 * The part of the rule the native side owns. The Flutter app already chose and ordered the tasks,
 * so here they are only split by the local day, cut to what fits and grouped.
 */
object WidgetAgenda {
  fun content(snapshot: WidgetSnapshot?, today: String, capacity: Int): WidgetContent {
    if (snapshot == null) return WidgetContent.AppIcon
    val strings = snapshot.strings
    if (!snapshot.signedIn) return WidgetContent.SignedOut(strings.signedOut)
    val coversUntil = snapshot.coversUntil
    val pendingCount = strings.pendingCount
    val overdueCount = strings.overdueCount
    if (
        snapshot.version > WidgetSnapshot.SUPPORTED_VERSION ||
            coversUntil == null ||
            today > coversUntil ||
            pendingCount == null ||
            overdueCount == null
    ) {
      return WidgetContent.Message(strings.header, strings.stale)
    }

    // ISO days compare in calendar order.
    val todays = snapshot.tasks.filter { it.dueDate == today }
    val overdue = snapshot.tasks.count { it.dueDate < today }
    if (todays.isEmpty() && overdue == 0) return WidgetContent.Message(strings.header, strings.empty)

    // The overdue group always takes a row. When today's tasks do not all fit, one more row goes
    // to the group of the oldest ones.
    val free = (capacity - if (overdue > 0) 1 else 0).coerceAtLeast(0)
    val shown = if (todays.size <= free) todays.size else (free - 1).coerceAtLeast(0)
    val pending = todays.size - shown
    return WidgetContent.Tasks(
        header = strings.header,
        overdue = if (overdue > 0) overdueCount.format(overdue) else null,
        pending = if (pending > 0) pendingCount.format(pending) else null,
        rows = todays.take(shown).map { WidgetRow(it.id, it.title) },
    )
  }

  fun isoDay(timeMillis: Long, timeZone: TimeZone): String {
    val calendar = Calendar.getInstance(timeZone).apply { timeInMillis = timeMillis }
    return String.format(
        Locale.ROOT,
        "%04d-%02d-%02d",
        calendar.get(Calendar.YEAR),
        calendar.get(Calendar.MONTH) + 1,
        calendar.get(Calendar.DAY_OF_MONTH),
    )
  }

  /**
   * Time from [nowMillis] until [marginMillis] past the next local midnight. Computed with the
   * calendar, so days of 23 or 25 hours around daylight saving changes still land on midnight.
   */
  fun millisUntilNextMidnight(
      nowMillis: Long,
      timeZone: TimeZone,
      marginMillis: Long = 30_000,
  ): Long {
    val midnight =
        Calendar.getInstance(timeZone).apply {
          timeInMillis = nowMillis
          add(Calendar.DAY_OF_MONTH, 1)
          set(Calendar.HOUR_OF_DAY, 0)
          set(Calendar.MINUTE, 0)
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
        }
    return midnight.timeInMillis + marginMillis - nowMillis
  }
}
