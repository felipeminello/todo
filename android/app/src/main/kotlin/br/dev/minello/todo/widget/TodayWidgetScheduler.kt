package br.dev.minello.todo.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * Redraws the widget from the stored snapshot, without network: shortly after each local midnight
 * so yesterday's tasks turn overdue, and every few hours as a safety net. WorkManager may delay the
 * midnight run by a few minutes while the device dozes; exact alarms would need a restricted
 * permission.
 */
object TodayWidgetScheduler {
  private const val MIDNIGHT_WORK = "today_widget_midnight"
  private const val PERIODIC_WORK = "today_widget_periodic"
  private const val PERIODIC_HOURS = 3L

  fun schedule(context: Context) {
    val workManager = WorkManager.getInstance(context)
    enqueueMidnight(workManager, ExistingWorkPolicy.REPLACE)
    workManager.enqueueUniquePeriodicWork(
        PERIODIC_WORK,
        ExistingPeriodicWorkPolicy.KEEP,
        PeriodicWorkRequestBuilder<TodayWidgetRedrawWorker>(PERIODIC_HOURS, TimeUnit.HOURS).build(),
    )
  }

  fun cancel(context: Context) {
    val workManager = WorkManager.getInstance(context)
    workManager.cancelUniqueWork(MIDNIGHT_WORK)
    workManager.cancelUniqueWork(PERIODIC_WORK)
  }

  internal fun enqueueMidnight(workManager: WorkManager, policy: ExistingWorkPolicy) {
    val delay =
        WidgetAgenda.millisUntilNextMidnight(System.currentTimeMillis(), TimeZone.getDefault())
    workManager.enqueueUniqueWork(
        MIDNIGHT_WORK,
        policy,
        OneTimeWorkRequestBuilder<TodayWidgetRedrawWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .setInputData(workDataOf(TodayWidgetRedrawWorker.REARM_MIDNIGHT to true))
            .build(),
    )
  }
}

class TodayWidgetRedrawWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {
  override suspend fun doWork(): Result {
    TodayWidget().updateAll(applicationContext)
    if (inputData.getBoolean(REARM_MIDNIGHT, false)) {
      // REPLACE would cancel this very run, which is still in progress.
      TodayWidgetScheduler.enqueueMidnight(
          WorkManager.getInstance(applicationContext),
          ExistingWorkPolicy.APPEND_OR_REPLACE,
      )
    }
    return Result.success()
  }

  companion object {
    const val REARM_MIDNIGHT = "rearmMidnight"
  }
}
