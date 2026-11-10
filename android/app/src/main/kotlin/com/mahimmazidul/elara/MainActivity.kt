package com.mahimmazidul.elara

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Elara's single activity.
 *
 * The app draws edge to edge: the window extends behind the status and
 * navigation bars and those bars are transparent, so the page background runs
 * to the physical edges of the display instead of stopping at a grey band.
 * That grey band was a real, observed defect — the first Android 13 emulator
 * render showed the app as a rectangle dropped onto the screen, with a
 * detached status bar above it.
 *
 * Drawing behind the bars is only half of it. The insets still have to be
 * honoured, or content ends up under the clock or the gesture handle:
 *
 *  * Flutter's own `SafeArea` widgets read the view padding, which Android
 *    still reports for the system bars, so the screens that already use
 *    `SafeArea` stay clear of them.
 *  * The navigation bar is the exception. When the app draws behind the
 *    gesture area, the bottom inset has to reach the navigation bar's own
 *    padding as well, otherwise the bottom of the app's navigation sits
 *    under the gesture handle.
 *
 * The colour of the system bar icons follows the app's theme, so the clock
 * stays legible on both a light and a dark background. Flutter sets the icon
 * brightness per screen — see `lib/theme/system_overlay_style.dart`; this only
 * makes sure the *bars* are transparent and that the window does not draw its
 * own opaque background over them.
 */
class MainActivity : FlutterActivity() {

    /**
     * The verification channel, set up in a debug build only.
     */
    private var verificationChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Deliberately NOT androidx's `enableEdgeToEdge()`. That helper is
        // designed for apps whose bars sit on their own surfaces, and it
        // paints a translucent scrim over the status and navigation bars to
        // guarantee contrast. On Elara that scrim is exactly the grey band
        // this activity exists to remove. The scrim is also applied *after*
        // `super.onCreate`, so anything set here in `onCreate` would be
        // overwritten by it.
        super.onCreate(savedInstanceState)

        // Ask the window to lay out behind the system bars.
        enableLayoutBehindSystemBars()

        // Make the bars themselves transparent, and stop the platform adding
        // its own contrast scrim on top. `setStatusBarContrastEnforced(false)`
        // and `setNavigationBarContrastEnforced(false)` are the API 29+
        // equivalents of the `*ContrastEnforced` flags in Flutter's
        // `SystemUiOverlayStyle`; without them Android draws its own
        // translucent grey over the navigation bar.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }

        // The verification intent, if there is one, is handled after the
        // engine is configured - the channel does not exist until then. See
        // configureFlutterEngine.
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The window background is transparent so the Flutter surface, which
        // paints the app's own page colour, is what shows through. Without
        // this the system paints an opaque window background over the area
        // behind the bars.
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        // The verification channel. See _registerVerificationChannel in
        // lib/main.dart for why the notification has to be posted by the app
        // rather than by the system's own command.
        //
        // Registered only in a debug build, so a release APK has no channel
        // at all and nothing can ask it to post a notification on demand.
        if (BuildConfig.DEBUG) {
            val channel =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VERIFICATION_CHANNEL)
            verificationChannel = channel
            // The Dart side owns the decision; this only carries the
            // request across and reports whether it was answered.
            //
            // The channel is held in a local rather than read back from the
            // field: Kotlin cannot prove the field is not null inside a
            // lambda, because the field is mutable and could have been
            // changed since.
            channel.setMethodCallHandler { call, result ->
                channel.invokeMethod(VERIFICATION_METHOD, call.arguments)
                result.success(null)
            }
        }

        // An intent that asks for a verification action may be the one that
        // launched the activity. It is handled here, after the channel
        // exists - in onCreate the channel is not set up yet, and a request
        // sent then would be silently dropped.
        handleVerificationIntent(intent)
    }

    /**
     * Handles an intent that asks for a verification action.
     *
     * The action arrives as an extra on the launch intent, so it can be sent
     * with `adb shell am start -n <activity> --es elara_verification <action>`.
     *
     * The extra is only read in a debug build, so a release APK ignores it.
     */
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleVerificationIntent(intent)
    }

    /**
     * Runs the verification action the intent asks for, if there is one.
     */
    private fun handleVerificationIntent(intent: android.content.Intent?) {
        if (!BuildConfig.DEBUG) return
        val action = intent?.getStringExtra(EXTRA_VERIFICATION) ?: return
        val channel = verificationChannel ?: return
        // The reply is logged, so that a request which never reaches Dart is
        // distinguishable from one that reaches Dart and fails there.
        channel.invokeMethod(VERIFICATION_METHOD, action, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.i(TAG, "verification action '$action' succeeded: $result")
            }

            override fun error(code: String, message: String?, details: Any?) {
                Log.i(TAG, "verification action '$action' failed: $code $message")
            }

            override fun notImplemented() {
                Log.i(TAG, "verification action '$action' was not implemented")
            }
        })
    }

    companion object {
        private const val TAG = "Elara"

        /**
         * The channel the Android verification uses to ask the app to post a
         * notification, so that the small icon can be seen in the status bar.
         */
        const val VERIFICATION_CHANNEL = "elara/verification"

        /**
         * The name of the intent extra that carries the request.
         */
        const val EXTRA_VERIFICATION = "elara_verification"

        /**
         * The method the request is delivered on. The action itself travels
         * as the argument.
         */
        const val VERIFICATION_METHOD = "handleVerification"
    }

    /**
     * Asks the window to lay out behind the system bars.
     *
     * `setDecorFitsSystemWindows(false)` is the modern form and works on every
     * API level this app supports. The legacy `systemUiVisibility` flags are
     * still set as well, because `setDecorFitsSystemWindows` was only added in
     * API 30 and the app supports API 24 and up.
     */
    private fun enableLayoutBehindSystemBars() {
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            window.decorView.systemUiVisibility or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
    }
}
