package io.github.fraidotube.gpspointer

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var guidanceToneGenerator: ToneGenerator? = null

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

    override fun onDestroy() {
        guidanceToneGenerator?.stopTone()
        guidanceToneGenerator?.release()
        guidanceToneGenerator = null
        super.onDestroy()
    }
}
