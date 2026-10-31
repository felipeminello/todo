package br.dev.minello.todo.widget

import org.json.JSONException
import org.json.JSONObject

/**
 * The JSON the Flutter app writes (`WidgetSnapshotCodec` in Dart). Both sides must change together
 * with [SUPPORTED_VERSION].
 */
data class WidgetSnapshot(
    val version: Int,
    val signedIn: Boolean,
    /** `YYYY-MM-DD`; `null` when signed out. */
    val coversUntil: String?,
    /** Most recent due date first, then most recently created first. */
    val tasks: List<Task>,
    val strings: Strings,
) {
  data class Task(
      val id: String,
      val title: String,
      /** `YYYY-MM-DD`, a calendar day with no time zone. */
      val dueDate: String,
  )

  /** A text whose count only the widget knows. */
  data class CountText(val one: String, val other: String) {
    fun format(count: Int): String =
        if (count == 1) one else other.replace(COUNT_TOKEN, count.toString())

    companion object {
      /** Must match `WidgetCountText.countToken` in Dart. */
      const val COUNT_TOKEN = "{count}"
    }
  }

  data class Strings(
      val header: String,
      val empty: String,
      val stale: String,
      val signedOut: String,
      /** `null` in snapshots older than version 2, which then read as stale. */
      val pendingCount: CountText?,
      val overdueCount: CountText?,
  )

  companion object {
    const val SUPPORTED_VERSION = 2

    /** Must match `HomeWidgetTaskPublisher.snapshotKey` in Dart. */
    const val STORAGE_KEY = "today_widget_snapshot"

    /** `null` when [json] is missing or malformed. */
    fun parse(json: String?): WidgetSnapshot? {
      if (json == null) return null
      return try {
        val root = JSONObject(json)
        val strings = root.getJSONObject("strings")
        val tasks = root.getJSONArray("tasks")
        WidgetSnapshot(
            version = root.getInt("version"),
            signedIn = root.getBoolean("signedIn"),
            coversUntil = if (root.isNull("coversUntil")) null else root.getString("coversUntil"),
            tasks =
                List(tasks.length()) { index ->
                  val task = tasks.getJSONObject(index)
                  Task(
                      id = task.getString("id"),
                      title = task.getString("title"),
                      dueDate = task.getString("dueDate"),
                  )
                },
            strings =
                Strings(
                    header = strings.getString("header"),
                    empty = strings.getString("empty"),
                    stale = strings.getString("stale"),
                    signedOut = strings.getString("signedOut"),
                    pendingCount = strings.optJSONObject("pendingCount")?.let(::parseCountText),
                    overdueCount = strings.optJSONObject("overdueCount")?.let(::parseCountText),
                ),
        )
      } catch (_: JSONException) {
        null
      }
    }

    private fun parseCountText(json: JSONObject) =
        CountText(one = json.getString("one"), other = json.getString("other"))
  }
}
