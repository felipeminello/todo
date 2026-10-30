package br.dev.minello.todo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.updateAll
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Must match `HomeWidgetStorage.androidReceiver` in Dart. */
class TodayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayWidget>() {
  override val glanceAppWidget = TodayWidget()

  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    TodayWidgetScheduler.schedule(context)
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
  ) {
    super.onUpdate(context, appWidgetManager, appWidgetIds)
    TodayWidgetScheduler.schedule(context)
  }

  override fun onDisabled(context: Context) {
    super.onDisabled(context)
    TodayWidgetScheduler.cancel(context)
  }

  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED -> {
        // The next midnight moved with the clock or the zone.
        TodayWidgetScheduler.schedule(context)
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
          try {
            TodayWidget().updateAll(context)
          } finally {
            pending.finish()
          }
        }
      }
      else -> super.onReceive(context, intent)
    }
  }
}
