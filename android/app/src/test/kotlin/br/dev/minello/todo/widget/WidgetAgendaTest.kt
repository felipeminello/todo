package br.dev.minello.todo.widget

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The widget's own share of the rule: split by the local day, cut to what fits, group the rest.
 * Ordering is the Flutter app's job and is tested there.
 */
class WidgetAgendaTest {
  private val strings =
      """{"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",""" +
          """"signedOut":"Entre no app para ver suas tarefas",""" +
          """"pendingCount":{"one":"1 tarefa pendente","other":"{count} tarefas pendentes"},""" +
          """"overdueCount":{"one":"1 tarefa atrasada","other":"{count} tarefas atrasadas"}}"""

  private fun snapshot(
      version: Int = 2,
      signedIn: Boolean = true,
      coversUntil: String? = "2026-11-05",
      tasks: List<Pair<String, String>> = emptyList(),
      strings: String = this.strings,
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

  /**
   * Rows top to bottom, as drawn: overdue group, pending group, then today's tasks from the oldest
   * to the most recent.
   */
  private fun lines(content: WidgetContent): List<String> {
    val tasks = content as? WidgetContent.Tasks ?: return emptyList()
    return listOfNotNull(tasks.overdue, tasks.pending) + tasks.rows.asReversed().map { it.id }
  }

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

    assertEquals(listOf("today"), lines(content))
  }

  @Test
  fun `groups overdue tasks instead of listing them`() {
    val content =
        WidgetAgenda.content(
            snapshot(
                tasks =
                    listOf(
                        "today" to "2026-10-29",
                        "late" to "2026-10-28",
                        "later" to "2026-10-20",
                    )
            ),
            "2026-10-29",
            8,
        )

    assertEquals(
        WidgetContent.Tasks(
            header = "Hoje",
            overdue = "2 tarefas atrasadas",
            pending = null,
            rows = listOf(WidgetRow("today", "Task today")),
        ),
        content,
    )
  }

  @Test
  fun `a single overdue task uses the singular`() {
    val content =
        WidgetAgenda.content(snapshot(tasks = listOf("late" to "2026-10-28")), "2026-10-29", 3)

    assertEquals(listOf("1 tarefa atrasada"), lines(content))
  }

  @Test
  fun `everything fits without a pending group`() {
    val content =
        WidgetAgenda.content(
            snapshot(
                tasks = listOf("t3" to "2026-10-29", "t2" to "2026-10-29", "t1" to "2026-10-29")
            ),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("t1", "t2", "t3"), lines(content))
  }

  @Test
  fun `groups the oldest of today when they do not fit`() {
    val content =
        WidgetAgenda.content(
            snapshot(
                tasks =
                    listOf(
                        "t4" to "2026-10-29",
                        "t3" to "2026-10-29",
                        "t2" to "2026-10-29",
                        "t1" to "2026-10-29",
                    )
            ),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("2 tarefas pendentes", "t3", "t4"), lines(content))
  }

  @Test
  fun `the overdue group takes a row before the pending one`() {
    val content =
        WidgetAgenda.content(
            snapshot(
                tasks =
                    listOf(
                        "t3" to "2026-10-29",
                        "t2" to "2026-10-29",
                        "t1" to "2026-10-29",
                        "o1" to "2026-10-28",
                    )
            ),
            "2026-10-29",
            3,
        )

    assertEquals(listOf("1 tarefa atrasada", "2 tarefas pendentes", "t3"), lines(content))
  }

  @Test
  fun `tomorrow's task becomes today's and today's becomes overdue`() {
    val data = snapshot(tasks = listOf("b" to "2026-10-30", "a" to "2026-10-29"))

    assertEquals(listOf("a"), lines(WidgetAgenda.content(data, "2026-10-29", 3)))
    assertEquals(
        listOf("1 tarefa atrasada", "b"),
        lines(WidgetAgenda.content(data, "2026-10-30", 3)),
    )
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

    assertEquals(listOf("1 tarefa atrasada"), lines(WidgetAgenda.content(data, "2026-11-05", 3)))
    assertEquals(
        WidgetContent.Message("Hoje", "Abra o app para atualizar"),
        WidgetAgenda.content(data, "2026-11-06", 3),
    )
  }

  @Test
  fun `newer format is stale`() {
    assertEquals(
        WidgetContent.Message("Hoje", "Abra o app para atualizar"),
        WidgetAgenda.content(snapshot(version = 3), "2026-10-29", 3),
    )
  }

  @Test
  fun `older format without group texts is stale`() {
    val v1Strings =
        """{"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",""" +
            """"signedOut":"Entre no app para ver suas tarefas","overdue":"Atrasada"}"""
    val data = snapshot(version = 1, tasks = listOf("a" to "2026-10-29"), strings = v1Strings)

    assertEquals(
        WidgetContent.Message("Hoje", "Abra o app para atualizar"),
        WidgetAgenda.content(data, "2026-10-29", 3),
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
