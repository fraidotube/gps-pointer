package io.github.fraidotube.gpspointer

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.provider.OpenableColumns
import android.provider.Settings
import android.net.Uri
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var guidanceToneGenerator: ToneGenerator? = null
    private var simulationFileChannel: MethodChannel? = null
    private var pendingSimulationFile: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/device_orientation",
        ).setMethodCallHandler { call, result ->
            if (call.method != "readOrientationInfo") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val latitude = call.argument<Double>("latitude")
            val longitude = call.argument<Double>("longitude")
            val altitude = call.argument<Double>("altitudeMeters")
            val timestamp = call.argument<Number>("timestampMillis")?.toLong()
            if (latitude == null || longitude == null || altitude == null || timestamp == null) {
                result.error("invalid_arguments", "Coordinate non valide.", null)
                return@setMethodCallHandler
            }

            val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val hasMagnetometer =
                sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null
            val field = GeomagneticField(
                latitude.toFloat(),
                longitude.toFloat(),
                altitude.toFloat(),
                timestamp,
            )
            result.success(
                mapOf(
                    "hasMagnetometer" to hasMagnetometer,
                    "declinationDegrees" to field.declination.toDouble(),
                ),
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/app_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    try {
                        val appUri = Uri.parse("package:$packageName")
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            appUri,
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        simulationFileChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/simulation_file",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingSimulation" -> {
                        val payload = pendingSimulationFile ?: readSimulationIntent(intent)
                        pendingSimulationFile = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        readSimulationIntent(intent)?.let {
            pendingSimulationFile = it
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/guidance_audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playBeep" -> {
                    toneGenerator().stopTone()
                    toneGenerator().startTone(ToneGenerator.TONE_PROP_BEEP, 90)
                    result.success(null)
                }
                "startContinuous" -> {
                    toneGenerator().stopTone()
                    toneGenerator().startTone(ToneGenerator.TONE_DTMF_5)
                    result.success(null)
                }
                "stop" -> {
                    guidanceToneGenerator?.stopTone()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun toneGenerator(): ToneGenerator =
        guidanceToneGenerator ?: ToneGenerator(AudioManager.STREAM_MUSIC, 80).also {
            guidanceToneGenerator = it
        }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = readSimulationIntent(intent) ?: return
        val channel = simulationFileChannel
        if (channel == null) {
            pendingSimulationFile = payload
        } else {
            channel.invokeMethod("simulationFileOpened", payload)
        }
    }

    private fun readSimulationIntent(sourceIntent: Intent?): Map<String, String>? {
        if (sourceIntent?.action != Intent.ACTION_VIEW) return null
        val uri = sourceIntent.data ?: return null
        val name = queryDisplayName(uri) ?: "simulation.gpspsim"

        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val bytes = input.use { stream ->
                val buffer = ByteArray(8192)
                val output = java.io.ByteArrayOutputStream()
                var total = 0
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > 8 * 1024 * 1024) return null
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            mapOf(
                "name" to name,
                "content" to bytes.toString(Charsets.UTF_8),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: android.net.Uri): String? {
        if (uri.scheme != "content") return uri.lastPathSegment
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else uri.lastPathSegment
            } else {
                uri.lastPathSegment
            }
        } finally {
            cursor?.close()
        }
    }

    override fun onDestroy() {
        guidanceToneGenerator?.stopTone()
        guidanceToneGenerator?.release()
        guidanceToneGenerator = null
        simulationFileChannel?.setMethodCallHandler(null)
        simulationFileChannel = null
        super.onDestroy()
    }
}
