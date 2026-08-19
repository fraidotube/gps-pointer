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
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.os.Build
import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {
    private var guidanceToneGenerator: ToneGenerator? = null
    private var simulationFileChannel: MethodChannel? = null
    private var pendingSimulationFile: Map<String, String>? = null
    private var rotationVectorSensorManager: SensorManager? = null
    private var rotationVectorListener: SensorEventListener? = null
    private var rotationVectorEventChannel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/device_orientation",
        ).setMethodCallHandler { call, result ->
            val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            when (call.method) {
                "readOrientationInfo" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val altitude = call.argument<Double>("altitudeMeters")
                    val timestamp = call.argument<Number>("timestampMillis")?.toLong()
                    if (latitude == null || longitude == null || altitude == null || timestamp == null) {
                        result.error("invalid_arguments", "Coordinate non valide.", null)
                        return@setMethodCallHandler
                    }

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

                "readDeviceInfo" -> {
                    fun sensorName(type: Int): String? =
                        sensorManager.getDefaultSensor(type)?.name
                    fun sensorVendor(type: Int): String? =
                        sensorManager.getDefaultSensor(type)?.vendor

                    result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "device" to Build.DEVICE,
                            "androidRelease" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "magnetometerName" to sensorName(Sensor.TYPE_MAGNETIC_FIELD),
                            "magnetometerVendor" to sensorVendor(Sensor.TYPE_MAGNETIC_FIELD),
                            "accelerometerName" to sensorName(Sensor.TYPE_ACCELEROMETER),
                            "accelerometerVendor" to sensorVendor(Sensor.TYPE_ACCELEROMETER),
                            "gyroscopeName" to sensorName(Sensor.TYPE_GYROSCOPE),
                            "gyroscopeVendor" to sensorVendor(Sensor.TYPE_GYROSCOPE),
                            "rotationVectorName" to sensorName(Sensor.TYPE_ROTATION_VECTOR),
                            "geomagneticRotationVectorName" to
                                sensorName(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR),
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }

        rotationVectorSensorManager =
            getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationVectorEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.fraidotube.gpspointer/rotation_vector",
        ).also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val manager = rotationVectorSensorManager ?: return
                    val sensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                    if (sensor == null) {
                        events?.error(
                            "rotation_vector_unavailable",
                            "Rotation Vector non disponibile.",
                            null,
                        )
                        return
                    }
                    rotationVectorListener?.let { listener -> manager.unregisterListener(listener) }
                    rotationVectorListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            if (event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) return
                            val matrix = FloatArray(9)
                            SensorManager.getRotationMatrixFromVector(matrix, event.values)
                            val orientation = FloatArray(3)
                            SensorManager.getOrientation(matrix, orientation)

                            val cameraMatrix = FloatArray(9)
                            val cameraRemapOk = SensorManager.remapCoordinateSystem(
                                matrix,
                                SensorManager.AXIS_X,
                                SensorManager.AXIS_Z,
                                cameraMatrix,
                            )
                            val cameraOrientation = FloatArray(3)
                            if (cameraRemapOk) {
                                SensorManager.getOrientation(cameraMatrix, cameraOrientation)
                            }

                            fun degrees(rad: Float): Double {
                                var value = Math.toDegrees(rad.toDouble()) % 360.0
                                if (value < 0.0) value += 360.0
                                return value
                            }

                            val quaternion = FloatArray(4)
                            SensorManager.getQuaternionFromVector(quaternion, event.values)
                            events?.success(
                                mapOf(
                                    "timestampNs" to event.timestamp,
                                    "accuracy" to event.accuracy,
                                    "azimuthDeg" to degrees(orientation[0]),
                                    "pitchDeg" to Math.toDegrees(orientation[1].toDouble()),
                                    "rollDeg" to Math.toDegrees(orientation[2].toDouble()),
                                    "cameraAzimuthDeg" to
                                        if (cameraRemapOk) degrees(cameraOrientation[0]) else null,
                                    "quaternionW" to quaternion[0].toDouble(),
                                    "quaternionX" to quaternion[1].toDouble(),
                                    "quaternionY" to quaternion[2].toDouble(),
                                    "quaternionZ" to quaternion[3].toDouble(),
                                ),
                            )
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                    }
                    manager.registerListener(
                        rotationVectorListener,
                        sensor,
                        SensorManager.SENSOR_DELAY_GAME,
                    )
                }

                override fun onCancel(arguments: Any?) {
                    val manager = rotationVectorSensorManager
                    val listener = rotationVectorListener
                    if (manager != null && listener != null) {
                        manager.unregisterListener(listener)
                    }
                    rotationVectorListener = null
                }
            })
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
        rotationVectorListener?.let { listener ->
            rotationVectorSensorManager?.unregisterListener(listener)
        }
        rotationVectorListener = null
        rotationVectorEventChannel?.setStreamHandler(null)
        rotationVectorEventChannel = null
        rotationVectorSensorManager = null
        super.onDestroy()
    }
}
