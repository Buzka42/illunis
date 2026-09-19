package com.illunis.illunis

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

/**
 * Health Connect bridge (R6).
 *
 * Channel `illunis/health_connect`:
 * - `isAvailable` → Bool. True only when the provider SDK is present
 *   ([HealthConnectClient.SDK_AVAILABLE]).
 * - `requestPermissions` → Bool. Launches the Health Connect permission
 *   sheet; if the provider is missing/outdated the owner is redirected to
 *   install/update it (Play Store) and false is returned.
 * - `getDailyData {date: ISO-8601}` → Map or null. Per-local-day totals:
 *   steps, sleepHours, restingHr, activeMinutes, caloriesBurned, plus
 *   `granted` (permissions actually held) and `day`. Denied metrics stay
 *   absent (null) — partial data, never estimated.
 * - `openHealthConnect` → null. Opens the provider (install page when
 *   missing, app settings otherwise).
 *
 * Garmin note: Garmin Connect Mobile syncs into Health Connect
 * opportunistically, so freshly finished workouts can lag by minutes to
 * hours. Numbers returned here are "as last synced" — staleness is
 * inherent, not a read error.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "IllunisHealth"
        private const val CHANNEL = "illunis/health_connect"
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
        private const val PLAY_URL =
            "https://play.google.com/store/apps/details?id=$PROVIDER_PACKAGE"
    }

    private val permissions: Set<String> = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
    )

    private lateinit var permissionContract:
        androidx.activity.result.contract.ActivityResultContract<Set<String>, Set<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val scope = CoroutineScope(Dispatchers.IO)
    private val permissionRequestCode = 9001

    override fun onCreate(savedInstanceState: Bundle?) {
        permissionContract =
            PermissionController.createRequestPermissionResultContract()
        super.onCreate(savedInstanceState)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == permissionRequestCode) {
            val granted = try {
                permissionContract.parseResult(resultCode, data)
            } catch (e: Exception) {
                Log.w(TAG, "permission parse failed", e)
                emptySet<String>()
            }
            Log.i(TAG, "permission result granted=$granted")
            pendingPermissionResult?.success(granted.containsAll(permissions))
            pendingPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IllunisDreamService.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDreamSettings" -> {
                        startActivity(Intent(Settings.ACTION_DREAM_SETTINGS))
                        result.success(null)
                    }
                    "finish" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(isAvailable())
                    "requestPermissions" -> requestPermissions(result)
                    "getDailyData" -> getDailyData(call.argument<String>("date"), result)
                    "openHealthConnect" -> {
                        openHealthConnect()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAvailable(): Boolean {
        val status = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        Log.i(TAG, "sdkStatus=$status")
        return status == HealthConnectClient.SDK_AVAILABLE
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        if (!isAvailable()) {
            openHealthConnect()
            result.success(false)
            return
        }
        pendingPermissionResult = result
        try {
            startActivityForResult(
                permissionContract.createIntent(this, permissions),
                permissionRequestCode,
            )
        } catch (e: Exception) {
            Log.w(TAG, "permission launch failed", e)
            pendingPermissionResult = null
            result.success(false)
        }
    }

    private fun getDailyData(dateArg: String?, result: MethodChannel.Result) {
        if (!isAvailable()) {
            result.success(null)
            return
        }
        val day = try {
            LocalDate.parse(dateArg!!.substring(0, 10))
        } catch (e: Exception) {
            Log.w(TAG, "bad date arg: $dateArg", e)
            result.success(null)
            return
        }
        scope.launch {
            try {
                result.success(readDay(day))
            } catch (e: SecurityException) {
                // Permissions revoked mid-read: return what we could compute.
                Log.w(TAG, "denied mid-read, returning partial", e)
                try {
                    result.success(readDay(day, partial = true))
                } catch (e2: Exception) {
                    Log.w(TAG, "partial read failed", e2)
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.w(TAG, "getDailyData failed", e)
                result.success(null)
            }
        }
    }

    private suspend fun readDay(day: LocalDate, partial: Boolean = false): Map<String, Any?> {
        val client = HealthConnectClient.getOrCreate(this)
        val granted = try {
            client.permissionController.getGrantedPermissions()
        } catch (e: Exception) {
            Log.w(TAG, "granted-permissions check failed", e)
            emptySet<String>()
        }
        val zone = ZoneId.systemDefault()
        val start = day.atStartOfDay(zone).toInstant()
        val end = day.plusDays(1).atStartOfDay(zone).toInstant()
        val range = TimeRangeFilter.between(start, end)

        var steps: Long? = null
        var calories: Double? = null
        var activeMinutes: Double? = null
        if (granted.contains(HealthPermission.getReadPermission(StepsRecord::class))) {
            steps = client.aggregate(
                AggregateRequest(setOf(StepsRecord.COUNT_TOTAL), range),
            )[StepsRecord.COUNT_TOTAL]
        }
        if (granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))) {
            calories = client.aggregate(
                AggregateRequest(setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL), range),
            )[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories
        }
        if (granted.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class))) {
            val secs = client.aggregate(
                AggregateRequest(setOf(ExerciseSessionRecord.EXERCISE_DURATION_TOTAL), range),
            )[ExerciseSessionRecord.EXERCISE_DURATION_TOTAL]?.seconds
            if (secs != null) activeMinutes = secs / 60.0
        }

        var sleepHours: Double? = null
        if (granted.contains(HealthPermission.getReadPermission(SleepSessionRecord::class))) {
            val sessions = client.readRecords(
                ReadRecordsRequest(SleepSessionRecord::class, range),
            ).records
            var totalSecs = 0L
            for (s in sessions) {
                totalSecs += java.time.Duration.between(s.startTime, s.endTime).seconds
            }
            if (sessions.isNotEmpty()) {
                sleepHours = (totalSecs / 3600.0).coerceIn(0.0, 24.0)
            }
        }

        var restingHr: Long? = null
        if (granted.contains(HealthPermission.getReadPermission(RestingHeartRateRecord::class))) {
            val recs = client.readRecords(
                ReadRecordsRequest(RestingHeartRateRecord::class, range),
            ).records
            val latest = recs.maxByOrNull { it.time }
            restingHr = latest?.beatsPerMinute?.toLong()
        }
        if (restingHr == null &&
            granted.contains(HealthPermission.getReadPermission(HeartRateRecord::class))
        ) {
            // Fallback: floor of the day's heart-rate series (no resting record).
            val recs = client.readRecords(
                ReadRecordsRequest(HeartRateRecord::class, range),
            ).records
            val min = recs.flatMap { it.samples }.minOfOrNull { it.beatsPerMinute }
            restingHr = min
        }

        val out: Map<String, Any?> = mapOf(
            "steps" to steps,
            "sleepHours" to sleepHours,
            "restingHr" to restingHr,
            "activeMinutes" to activeMinutes,
            "caloriesBurned" to calories,
            "granted" to granted.toList().sorted(),
            "day" to day.toString(),
        )
        Log.i(
            TAG,
            "day=$day steps=$steps sleepH=$sleepHours rhr=$restingHr " +
                "activeMin=$activeMinutes kcal=$calories granted=${granted.size} " +
                (if (partial) "(partial)" else ""),
        )
        return out
    }

    private fun openHealthConnect() {
        try {
            val status = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
            if (status == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
                startActivity(
                    Intent(
                        HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS,
                    ),
                )
            } else {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_URL)))
            }
        } catch (e: Exception) {
            Log.w(TAG, "openHealthConnect failed", e)
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_URL)))
            } catch (e2: Exception) {
                Log.w(TAG, "play-store fallback failed", e2)
            }
        }
    }
}
