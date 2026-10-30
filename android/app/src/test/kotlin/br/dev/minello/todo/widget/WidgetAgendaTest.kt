package br.dev.minello.todo.widget

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The widget's own share of the rule: filter by the local day, cut to what fits, mark overdue.
 * Ordering is the Flutter app's job and is tested there.
 */
class WidgetAgendaTest {
  private val strings =
      """{"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",""" +
          """"signedOut":"Entre no app para ver suas tarefas","overdue":"Atrasada"}"""

  private fun snapshot(
      version: Int = 1,
      signedIn: Boolean = true,
      coversUntil: String? = "2026-11-05",
      tasks: List<Pair<String, String>> = emptyList(),
  ): WidgetSnapshot {
    val taskJson =
        tasks.joinToString(",") { (id, dueDate) ->
          """{"id":"$id","title":"Task $id","dueDate":"$dueDate",""" +
              """"createdAt":"2026-10-01T12:00:00.000Z"}"""
        }
    val covers = coversUntil?.let { ""","coversUntil":"$it"""" } ?: ""
    return WidgetSnapshot.parse(
        """{"version":$version,"signedIn":$signedIn,""" +
            """"generatedAt":"2026-10-29T13:02:00.000Z"$covers,""" +
            """"tasks":[$taskJson],"strings":$strings}"""
    )!!
  }

  private fun rows(content: WidgetContent): List<String> =
      (content as? WidgetContent.Tasks)?.rows?.map { it.id + if (it.isOverdue) "!" else "" }
          ?: emptyList()

  @Test
  fun `no snapshot shows only the icon`() {
    assertEquals(WidgetContent.AppIcon, WidgetAgenda.content(null, "2026-10-29", 3))
  }

  @Test
  fun `malformed json is no snapshot`() {
    assertNull(WidgetSnapshot.parse("""{"version":1}"""))
    assertNull(WidgetSnapshot.parse("not json"))
    assertNull(WidgetSnapshot.parse(null))
  }

  @Test
  fun `signed out shows the sign-in message`() {
    assertEquals(
        WidgetContent.SignedOut("Entre no app para ver suas tarefas"),
        WidgetAgenda.content(snapshot(signedIn = false, coversUntil = null), "2026-10-29", 3),
    )
  }

  @Test
  fun `drops tasks due after today`() {
    val content =
        WidgetAgenda.content(
            snapshot(tasks = listOf("tomorrow" to "2026-10-30", "today" to "2026-10-29")),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("today"), rows(content))
  }

  @Test
  fun `marks overdue tasks and labels them for screen readers`() {
    val content =
        WidgetAgenda.content(
            snapshot(tasks = listOf("today" to "2026-10-29", "late" to "2026-10-28")),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("today", "late!"), rows(content))
    val found = (content as WidgetContent.Tasks).rows
    assertEquals("Hoje", content.header)
    assertEquals("Atrasada: Task late", found[1].accessibilityLabel)
    assertEquals("Task today", found[0].accessibilityLabel)
  }

  @Test
  fun `cuts to capacity keeping the most recent`() {
    val content =
        WidgetAgenda.content(
            snapshot(
                tasks =
                    listOf(
                        "t2" to "2026-10-29",
                        "t1" to "2026-10-29",
                        "o1" to "2026-10-28",
                        "o2" to "2026-10-25",
                    )
            ),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("t2", "t1", "o1!"), rows(content))
  }

  @Test
  fun `tomorrow's task becomes today's and today's becomes overdue`() {
    val data = snapshot(tasks = listOf("b" to "2026-10-30", "a" to "2026-10-29"))

    assertEquals(listOf("a"), rows(WidgetAgenda.content(data, "2026-10-29", 3)))
    assertEquals(listOf("b", "a!"), rows(WidgetAgenda.content(data, "2026-10-30", 3)))
  }

  @Test
  fun `nothing due shows the empty message`() {
    assertEquals(
        WidgetContent.Message("Hoje", "Nada para hoje"),
        WidgetAgenda.content(snapshot(tasks = listOf("later" to "2026-11-02")), "2026-10-29", 3),
    )
  }

  @Test
  fun `past the horizon is stale`() {
    val data = snapshot(coversUntil = "2026-11-05", tasks = listOf("a" to "2026-10-29"))

    assertEquals(listOf("a!"), rows(WidgetAgenda.content(data, "2026-11-05", 3)))
    assertEquals(
        WidgetContent.Message("Hoje", "Abra o app para atualizar"),
        WidgetAgenda.content(data, "2026-11-06", 3),
    )
  }

  @Test
  fun `newer format is stale`() {
    assertEquals(
        WidgetContent.Message("Hoje", "Abra o app para atualizar"),
        WidgetAgenda.content(snapshot(version = 2), "2026-10-29", 3),
    )
  }

  @Test
  fun `iso day uses the given time zone`() {
    // 2026-10-30 01:30 UTC is still the 29th in São Paulo (UTC-3).
    val instant = utc(2026, 10, 30, 1, 30)

    assertEquals("2026-10-29", WidgetAgenda.isoDay(instant, TimeZone.getTimeZone("America/Sao_Paulo")))
    assertEquals("2026-10-30", WidgetAgenda.isoDay(instant, TimeZone.getTimeZone("UTC")))
  }

  @Test
  fun `next midnight is computed in the local day`() {
    val zone = TimeZone.getTimeZone("America/Sao_Paulo")
    val now = local(zone, 2026, 10, 29, 23, 0)

    val delay = WidgetAgenda.millisUntilNextMidnight(now, zone, marginMillis = 30_000)

    assertEquals(60 * 60_000L + 30_000L, delay)
    assertEquals("2026-10-30", WidgetAgenda.isoDay(now + delay, zone))
  }

  @Test
  fun `next midnight survives daylight saving changes`() {
    val zone = TimeZone.getTimeZone("America/New_York")
    // Clocks go back at 02:00 on 2026-11-01: that day has 25 hours.
    val now = local(zone, 2026, 11, 1, 0, 30)

    val delay = WidgetAgenda.millisUntilNextMidnight(now, zone, marginMillis = 0)

    assertEquals(24 * 3_600_000L + 30 * 60_000L, delay)
    val midnight = Calendar.getInstance(zone).apply { timeInMillis = now + delay }
    assertEquals(0, midnight.get(Calendar.HOUR_OF_DAY))
    assertEquals("2026-11-02", WidgetAgenda.isoDay(now + delay, zone))
  }

  @Test
  fun `rows that fit grow with the height and never drop below one`() {
    assertEquals(2, TodayWidget.rowsThatFit(110f))
    assertEquals(6, TodayWidget.rowsThatFit(180f))
    assertEquals(1, TodayWidget.rowsThatFit(40f))
  }

  private fun utc(year: Int, month: Int, day: Int, hour: Int, minute: Int) =
      local(TimeZone.getTimeZone("UTC"), year, month, day, hour, minute)

  private fun local(zone: TimeZone, year: Int, month: Int, day: Int, hour: Int, minute: Int) =
      Calendar.getInstance(zone)
          .apply {
            clear()
            set(year, month - 1, day, hour, minute)
          }
          .timeInMillis
}
