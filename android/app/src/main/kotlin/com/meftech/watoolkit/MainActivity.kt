package com.meftech.watoolkit

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val channelName = "com.meftech.watoolkit/share"
    private var shareChannel: MethodChannel? = null
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(pendingLink)
                else -> result.notImplemented()
            }
        }
        handleShareIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type == "text/plain") {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
            val link = extractUrl(text) ?: return
            pendingLink = link
            shareChannel?.invokeMethod("onSharedLink", link)
        }
    }

    private fun extractUrl(text: String): String? {
        val pattern = Pattern.compile("https?://[^\\s<>\"{}|\\\\^`\\[\\]]+")
        val matcher = pattern.matcher(text.trim())
        return if (matcher.find()) {
            matcher.group(0)?.replace(Regex("[)\\]},.!?]+$"), "")
        } else null
    }
}
