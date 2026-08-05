package com.tigersplus.attendance

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    // Channel name 은 클라이언트(htm_core/kiosk_lock.dart)와 일치해야 함.
    // staff/attendance 모두 같은 channel 을 쓰므로 'com.tigersplus.app/kiosk' 유지.
    private val channelName = "com.tigersplus.app/kiosk"

    // 아래 둘은 attendance 키오스크 전용 — 앱 고정 상태에서 시스템 상태바가 가려져
    // 배터리/충전 여부를 볼 수 없고 밝기도 못 바꾸는 문제 대응.
    // 클라이언트: apps/attendance/lib/services/device_power_service.dart
    private val deviceChannelName = "com.tigersplus.app/device"
    private val batteryChannelName = "com.tigersplus.app/battery"

    private var batteryReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 매장 태블릿은 출퇴근 단말이라 화면이 저절로 꺼지면 직원이 매번 깨워야 한다.
        // FLAG_KEEP_SCREEN_ON 은 물리 전원 버튼을 막지 않으므로 강제 소등은 그대로 가능.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        runOnUiThread {
                            try {
                                startLockTask()
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "stop" -> {
                        runOnUiThread {
                            try {
                                stopLockTask()
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "isLocked" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val mode = am.lockTaskModeState
                        result.success(mode != ActivityManager.LOCK_TASK_MODE_NONE)
                    }
                    "moveToBack" -> {
                        runOnUiThread {
                            try {
                                moveTaskToBack(true)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 창(window) 밝기만 조정한다. 시스템 밝기 변경은 WRITE_SETTINGS 권한이
                    // 필요한데 앱 고정(lock task) 상태에서는 권한 부여 화면 자체를 띄울 수
                    // 없어 쓰지 않는다. 키오스크는 항상 foreground 라 체감은 동일.
                    "setBrightness" -> {
                        val raw = (call.argument<Double>("value") ?: -1.0).toFloat()
                        runOnUiThread {
                            applyBrightness(raw)
                            result.success(true)
                        }
                    }
                    // 창 밝기 override 해제 → 시스템 밝기를 그대로 따라간다.
                    "clearBrightness" -> {
                        runOnUiThread {
                            applyBrightness(WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE)
                            result.success(true)
                        }
                    }
                    // 현재 창 밝기. override 가 없으면 음수(BRIGHTNESS_OVERRIDE_NONE).
                    "getBrightness" ->
                        result.success(window.attributes.screenBrightness.toDouble())
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, batteryChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // 재구독 시 이전 receiver 가 남지 않도록 먼저 정리.
                    unregisterBatteryReceiver()
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent == null) return
                            events?.success(batteryStateOf(intent))
                        }
                    }
                    batteryReceiver = receiver
                    // ACTION_BATTERY_CHANGED 는 sticky broadcast — registerReceiver 가
                    // 현재 상태 intent 를 즉시 돌려주므로 그걸로 초기값을 채운다.
                    val sticky = registerReceiver(
                        receiver,
                        IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                    )
                    if (sticky != null) events?.success(batteryStateOf(sticky))
                }

                override fun onCancel(arguments: Any?) {
                    unregisterBatteryReceiver()
                }
            },
        )
    }

    override fun onDestroy() {
        unregisterBatteryReceiver()
        super.onDestroy()
    }

    private fun unregisterBatteryReceiver() {
        batteryReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                // 등록된 적 없거나 이미 해제된 경우 — 무시.
            }
        }
        batteryReceiver = null
    }

    /// 화면이 완전히 꺼진 것처럼 어두워지면 키오스크를 되살릴 방법이 없으므로 하한을 둔다.
    /// 음수는 override 해제(BRIGHTNESS_OVERRIDE_NONE) 의미라 그대로 통과시킨다.
    private fun applyBrightness(value: Float) {
        val clamped = when {
            value < 0f -> WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            value < MIN_BRIGHTNESS -> MIN_BRIGHTNESS
            value > 1f -> 1f
            else -> value
        }
        val lp = window.attributes
        lp.screenBrightness = clamped
        window.attributes = lp
    }

    private fun batteryStateOf(intent: Intent): Map<String, Any> {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percent = if (level >= 0 && scale > 0) {
            (level * 100f / scale).roundToInt()
        } else {
            -1
        }
        val status = intent.getIntExtra(
            BatteryManager.EXTRA_STATUS,
            BatteryManager.BATTERY_STATUS_UNKNOWN,
        )
        // plugged = 케이블이 꽂혀 있는가, charging = 실제로 충전 중인가.
        // 완충되면 charging=false / full=true / plugged=true 가 되므로 셋을 나눠 보낸다.
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
        return mapOf(
            "level" to percent,
            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING),
            "full" to (status == BatteryManager.BATTERY_STATUS_FULL),
            "plugged" to plugged,
        )
    }

    private companion object {
        const val MIN_BRIGHTNESS = 0.05f
    }
}
