package dev.mcro.mcro

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissions.request" -> {
                val permissions = call.argument<List<String>>("permissions") ?: emptyList()
                requestPermissions(permissions, result)
            }
            "location.getCurrent" -> {
                val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 15_000L)
                    .coerceIn(1_000L, 60_000L)
                getCurrentLocation(timeoutMs, result)
            }
            "sms.send" -> sendSms(
                call.argument<String>("to") ?: "",
                call.argument<String>("message") ?: "",
                result
            )
            else -> result.notImplemented()
        }
    }

    // --- Permissions -----------------------------------------------------

    private fun requestPermissions(permissions: List<String>, result: MethodChannel.Result) {
        val needed = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (needed.isEmpty()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("BUSY", "Another permission request is already in progress.", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, needed.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return
        }
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null
        // At least one grant is enough: for location, coarse-only is usable,
        // and single-permission requests reduce to "the permission was granted".
        pending.success(grantResults.any { it == PackageManager.PERMISSION_GRANTED })
    }

    // --- Geolocation -----------------------------------------------------

    @SuppressLint("MissingPermission") // guards below check FINE/COARSE
    @Suppress("DEPRECATION") // requestSingleUpdate is deprecated but works everywhere
    private fun getCurrentLocation(timeoutMs: Long, result: MethodChannel.Result) {
        val locationManager = getSystemService(LocationManager::class.java)
        val fine = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            result.error("PERMISSION_DENIED", "Location permission not granted.", null)
            return
        }

        val providers = if (fine) {
            listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
        } else {
            listOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
        }

        // Prefer the most recent cached fix.
        var best: Location? = null
        for (provider in providers) {
            val location = try {
                locationManager.getLastKnownLocation(provider)
            } catch (e: SecurityException) {
                null
            } ?: continue
            if (best == null || location.time > best.time) {
                best = location
            }
        }
        if (best != null) {
            result.success(locationToMap(best))
            return
        }

        // No cached fix: wait for a fresh one, with a timeout.
        val provider = providers.firstOrNull { locationManager.isProviderEnabled(it) }
        if (provider == null) {
            result.error("POSITION_UNAVAILABLE", "No location provider is enabled.", null)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var completed = false
        var timeoutRunnable: Runnable? = null

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (completed) {
                    return
                }
                completed = true
                timeoutRunnable?.let { handler.removeCallbacks(it) }
                try {
                    locationManager.removeUpdates(this)
                } catch (e: SecurityException) {
                    // Already have the fix; nothing to clean up.
                }
                result.success(locationToMap(location))
            }
        }
        timeoutRunnable = Runnable {
            if (!completed) {
                completed = true
                try {
                    locationManager.removeUpdates(listener)
                } catch (e: SecurityException) {
                    // Ignore: we never got access in the first place.
                }
                result.error("TIMEOUT", "Timed out waiting for a location fix.", null)
            }
        }
        handler.postDelayed(timeoutRunnable!!, timeoutMs)
        try {
            locationManager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (e: SecurityException) {
            completed = true
            timeoutRunnable?.let { handler.removeCallbacks(it) }
            result.error("PERMISSION_DENIED", e.message ?: "Location permission denied.", null)
        }
    }

    private fun locationToMap(location: Location): Map<String, Any?> = mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
        "altitude" to if (location.hasAltitude()) location.altitude else null,
        "speed" to if (location.hasSpeed()) location.speed.toDouble() else null,
        "timestamp" to location.time
    )

    // --- SMS -------------------------------------------------------------

    @Suppress("DEPRECATION") // SmsManager.getDefault() is fine for single-SIM
    private fun sendSms(to: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                this, Manifest.permission.SEND_SMS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "SMS permission not granted.", null)
            return
        }
        if (to.isBlank()) {
            result.error("INVALID_ARGUMENT", "The \"to\" field is required.", null)
            return
        }
        try {
            SmsManager.getDefault().sendTextMessage(to, null, message, null, null)
            result.success(mapOf("sent" to true))
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message ?: "Failed to send the SMS.", null)
        }
    }

    companion object {
        private const val CHANNEL = "dev.mcro.mcro/platform"
        private const val PERMISSION_REQUEST_CODE = 4217
    }
}
