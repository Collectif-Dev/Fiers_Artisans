package com.fiersartisans.fiers_artisans_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		ensureDefaultNotificationChannel()
	}

	private fun ensureDefaultNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return
		}

		val channelId = "fiers_artisans_high_importance"
		val channelName = "Fiers Artisans"
		val channelDescription = "Alertes importantes"

		val manager = applicationContext.getSystemService<NotificationManager>() ?: return
		val existingChannel = manager.getNotificationChannel(channelId)
		if (existingChannel != null && existingChannel.importance >= NotificationManager.IMPORTANCE_HIGH) {
			return
		}

		val channel = NotificationChannel(
			channelId,
			channelName,
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = channelDescription
			enableVibration(true)
			setShowBadge(true)
		}

		manager.createNotificationChannel(channel)
	}
}
