package com.illunis.illunis

import android.graphics.Color
import android.service.dreams.DreamService
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/// Android screensaver: the same sky, on the lock screen, while charging.
///
/// The system binds this when the user picks Illunis as the screen saver.
/// It hosts a dedicated Flutter engine on the `dreamMain` entrypoint so the
/// nightstand composition is not the pager, and so the ticker keeps running
/// without an Activity in the resumed state.
class IllunisDreamService : DreamService() {
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isFullscreen = true
        isInteractive = true
        isScreenBright = true
        window?.addFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
        window?.decorView?.setBackgroundColor(Color.parseColor("#07090D"))

        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
        }

        val engine =
            FlutterEngine(this).also {
                GeneratedPluginRegistrant.registerWith(it)
                MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL)
                    .setMethodCallHandler { call, result ->
                        when (call.method) {
                            "finish" -> {
                                finish()
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    }
                it.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "dreamMain"),
                )
            }

        val view =
            FlutterView(this, FlutterTextureView(this)).also {
                it.attachToFlutterEngine(engine)
            }
        setContentView(view)

        this.engine = engine
        this.view = view
        engine.lifecycleChannel.appIsResumed()
        engine.lifecycleChannel.aWindowIsFocused()
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        engine?.lifecycleChannel?.appIsResumed()
        engine?.lifecycleChannel?.aWindowIsFocused()
    }

    override fun onDreamingStopped() {
        engine?.lifecycleChannel?.noWindowsAreFocused()
        engine?.lifecycleChannel?.appIsPaused()
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        view?.detachFromFlutterEngine()
        engine?.lifecycleChannel?.appIsDetached()
        engine?.destroy()
        view = null
        engine = null
        super.onDetachedFromWindow()
    }

    companion object {
        const val CHANNEL = "illunis/host"
    }
}
