package com.officialavora.app

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.officialavora.app/device"
        ).setMethodCallHandler { call, result ->
            if (call.method != "countryCode") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val telephony = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val code = telephony.networkCountryIso
                .takeIf { it.length == 2 }
                ?: telephony.simCountryIso.takeIf { it.length == 2 }
                ?: resources.configuration.locales[0].country
            result.success(code.uppercase())
        }
    }
}
