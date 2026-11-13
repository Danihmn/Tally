package com.example.mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (PRIVACY_SCREEN_ENABLED) {
            // FLAG_SECURE hides the app in the recent-apps switcher and blocks
            // screenshots and screen recording.
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }

    private companion object {
        // Privacy screen: set to true to enable it (see docs/ARCHITECTURE.md, "Privacy screen").
        const val PRIVACY_SCREEN_ENABLED = false
    }
}
