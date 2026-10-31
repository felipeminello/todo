package br.dev.minello.todo.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import br.dev.minello.todo.MainActivity
import br.dev.minello.todo.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.util.TimeZone

/** Read-only list of today's and overdue tasks; a tap anywhere opens the app. */
class TodayWidget : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode =
      SizeMode.Responsive(
          setOf(
              DpSize(110.dp, 110.dp),
              DpSize(110.dp, 180.dp),
              DpSize(250.dp, 110.dp),
              DpSize(250.dp, 180.dp),
              DpSize(250.dp, 250.dp),
              DpSize(250.dp, 320.dp),
              DpSize(250.dp, 400.dp),
          )
      )

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent {
      val preferences = currentState<HomeWidgetGlanceState>().preferences
      val snapshot = WidgetSnapshot.parse(preferences.getString(WidgetSnapshot.STORAGE_KEY, null))
      // The day is taken at render time, so any redraw after midnight or a
      // time zone change shows the new local day.
      val today = WidgetAgenda.isoDay(System.currentTimeMillis(), TimeZone.getDefault())
      val capacity = rowsThatFit(LocalSize.current.height.value)
      TodayContent(WidgetAgenda.content(snapshot, today, capacity))
    }
  }

  companion object {
    private const val PADDING_DP = 12f
    private const val HEADER_DP = 24f
    private const val ROW_DP = 22f

    fun rowsThatFit(heightDp: Float): Int =
        ((heightDp - 2 * PADDING_DP - HEADER_DP) / ROW_DP).toInt().coerceAtLeast(1)
  }
}

private val onBackground = ColorProvider(R.color.widget_on_background)
private val onBackgroundVariant = ColorProvider(R.color.widget_on_background_variant)
private val overdue = ColorProvider(R.color.widget_overdue)

@Composable
private fun TodayContent(content: WidgetContent) {
  val modifier =
      GlanceModifier.fillMaxSize()
          .background(ColorProvider(R.color.widget_background))
          .padding(12.dp)
          .clickable(actionStartActivity<MainActivity>())
  when (content) {
    WidgetContent.AppIcon ->
        Column(
            modifier = modifier,
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
          Image(
              provider = ImageProvider(R.mipmap.ic_launcher),
              contentDescription = null,
              modifier = GlanceModifier.size(48.dp),
          )
        }
    is WidgetContent.SignedOut ->
        Column(
            modifier = modifier,
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
          Text(
              text = content.text,
              style =
                  TextStyle(
                      color = onBackgroundVariant,
                      fontSize = 14.sp,
                      textAlign = TextAlign.Center,
                  ),
          )
        }
    is WidgetContent.Message ->
        Column(modifier = modifier) {
          Header(content.header)
          Spacer(GlanceModifier.defaultWeight())
          Text(
              text = content.text,
              style = TextStyle(color = onBackgroundVariant, fontSize = 14.sp),
          )
        }
    is WidgetContent.Tasks ->
        Column(modifier = modifier) {
          Header(content.header)
          // Anchors the list to the bottom edge.
          Spacer(GlanceModifier.defaultWeight())
          // Oldest at the top, most recent at the bottom.
          content.overdue?.let { OverdueGroup(it) }
          content.pending?.let { Line(it, onBackgroundVariant) }
          content.rows.asReversed().forEach { Line(it.title, onBackground) }
        }
  }
}

@Composable
private fun Header(text: String) {
  Text(
      text = text,
      style = TextStyle(color = onBackground, fontSize = 16.sp, fontWeight = FontWeight.Bold),
      modifier = GlanceModifier.semantics { contentDescription = text },
  )
}

@Composable
private fun OverdueGroup(text: String) {
  Row(
      modifier = GlanceModifier.fillMaxWidth().height(22.dp),
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Image(
        provider = ImageProvider(R.drawable.ic_widget_overdue),
        contentDescription = null,
        colorFilter = ColorFilter.tint(overdue),
        modifier = GlanceModifier.size(14.dp),
    )
    Spacer(GlanceModifier.width(4.dp))
    Text(text = text, maxLines = 1, style = TextStyle(color = overdue, fontSize = 14.sp))
  }
}

@Composable
private fun Line(text: String, color: ColorProvider) {
  Row(
      modifier = GlanceModifier.fillMaxWidth().height(22.dp),
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Text(text = text, maxLines = 1, style = TextStyle(color = color, fontSize = 14.sp))
  }
}
