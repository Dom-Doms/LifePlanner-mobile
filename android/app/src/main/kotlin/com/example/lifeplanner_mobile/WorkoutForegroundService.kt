package com.example.lifeplanner_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class WorkoutForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val tickRunnable = object : Runnable {
        override fun run() {
            handleTick()
            if (state.active && !state.finished) {
                handler.postDelayed(this, 1000)
            }
        }
    }

    private var state = WorkoutState()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startFromPayload(intent.getStringExtra(EXTRA_PAYLOAD))
            ACTION_UPDATE -> updateFromPayload(intent.getStringExtra(EXTRA_PAYLOAD))
            ACTION_PAUSE -> pauseWorkout()
            ACTION_RESUME -> resumeWorkout()
            ACTION_NEXT, ACTION_SKIP -> completeCurrentStep(manual = true)
            ACTION_PREVIOUS -> previousStep()
            ACTION_STOP -> stopWorkout(sendEvent = true)
            else -> restoreState()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    private fun startFromPayload(rawPayload: String?) {
        val payload = JSONObject(rawPayload ?: return)
        state = WorkoutState.fromJson(payload)
        state.active = true
        state.finished = false
        state.lastTickAt = SystemClock.elapsedRealtime()
        if (state.remainingTime <= 0) {
            state.remainingTime = state.currentStep()?.durationSeconds ?: 0
        }
        persistState()
        startForegroundNotification()
        scheduleTick()
        sendEvent("stateChanged")
    }

    private fun updateFromPayload(rawPayload: String?) {
        val payload = JSONObject(rawPayload ?: return)
        val previousRunId = state.runId
        state = WorkoutState.fromJson(payload)
        state.active = true
        state.finished = false
        state.lastTickAt = SystemClock.elapsedRealtime()
        if (state.remainingTime <= 0) {
            state.remainingTime = state.currentStep()?.durationSeconds ?: 0
        }
        persistState()
        if (previousRunId == 0) {
            startForegroundNotification()
        } else {
            updateNotification()
        }
        scheduleTick()
        sendEvent("stateChanged")
    }

    private fun pauseWorkout() {
        if (!state.active || state.finished) return
        updateElapsedFromClock()
        state.status = STATUS_PAUSED
        state.lastTickAt = SystemClock.elapsedRealtime()
        persistState()
        updateNotification()
        sendEvent("stateChanged")
    }

    private fun resumeWorkout() {
        if (!state.active || state.finished) return
        state.status = STATUS_IN_PROGRESS
        state.lastTickAt = SystemClock.elapsedRealtime()
        persistState()
        updateNotification()
        scheduleTick()
        sendEvent("stateChanged")
    }

    private fun previousStep() {
        if (!state.active || state.finished) return
        state.currentStepIndex = max(0, state.currentStepIndex - 1)
        state.remainingTime = state.currentStep()?.durationSeconds ?: 0
        state.lastTickAt = SystemClock.elapsedRealtime()
        persistState()
        updateNotification()
        sendEvent("stateChanged")
    }

    private fun completeCurrentStep(manual: Boolean) {
        if (!state.active || state.finished) return
        val step = state.currentStep()
        if (!manual && step?.isTimed != true) return
        if (!manual && step?.isTimed == true) {
            vibrateForStepCompletion()
            advanceStep(notifyState = false)
            sendEvent("stepCompleted")
            return
        }
        advanceStep()
    }

    private fun handleTick() {
        if (!state.active || state.finished || state.status == STATUS_PAUSED) return
        val step = state.currentStep() ?: return
        val deltaSeconds = updateElapsedFromClock()
        if (deltaSeconds <= 0 || !step.isTimed) {
            updateNotification()
            return
        }
        state.remainingTime -= deltaSeconds
        while (state.remainingTime <= 0 && state.currentStep()?.isTimed == true && !state.finished) {
            vibrateForStepCompletion()
            val overflow = -state.remainingTime
            advanceStep(notifyState = false)
            sendEvent("stepCompleted")
            if (state.currentStep()?.isTimed == true) {
                state.remainingTime -= overflow
            }
        }
        persistState()
        updateNotification()
        sendEvent("stateChanged")
    }

    private fun updateElapsedFromClock(): Int {
        val now = SystemClock.elapsedRealtime()
        val deltaSeconds = ((now - state.lastTickAt) / 1000L).toInt()
        if (deltaSeconds > 0) {
            state.elapsedSeconds += deltaSeconds
            state.lastTickAt += deltaSeconds * 1000L
        }
        return deltaSeconds
    }

    private fun advanceStep(notifyState: Boolean = true) {
        if (state.currentStepIndex >= state.sequence.lastIndex) {
            state.finished = true
            state.status = STATUS_COMPLETED
            state.remainingTime = 0
            state.active = false
            persistState()
            updateNotification()
            sendEvent("workoutCompleted")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        state.currentStepIndex += 1
        state.remainingTime = state.currentStep()?.durationSeconds ?: 0
        state.lastTickAt = SystemClock.elapsedRealtime()
        persistState()
        updateNotification()
        if (notifyState) sendEvent("stateChanged")
    }

    private fun stopWorkout(sendEvent: Boolean) {
        if (state.runId != 0) {
            state.active = false
            state.status = STATUS_CANCELLED
            persistState()
            if (sendEvent) sendEvent("serviceStopped")
        }
        handler.removeCallbacks(tickRunnable)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startForegroundNotification() {
        createNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        updateNotification()
    }

    private fun updateNotification() {
        if (!state.active && !state.finished) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val step = state.currentStep()
        val title = if (state.finished) "LifePlanner workout completato" else "LifePlanner workout in corso"
        val text = when {
            state.finished -> "Sequenza terminata"
            state.status == STATUS_PAUSED -> "Pausa - ${step?.displayText() ?: "Workout"}"
            step == null -> "Workout"
            step.isTimed -> "${step.label()} - ${formatDuration(state.remainingTime)}"
            else -> step.displayText()
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setSubText("${min(state.currentStepIndex + 1, state.sequence.size)} / ${state.sequence.size} step")
            .setContentIntent(openRunnerIntent())
            .setOngoing(state.active && !state.finished)
            .setOnlyAlertOnce(true)
            .addAction(togglePauseAction())
            .addAction(nextAction())
            .addAction(stopAction())
            .build()
    }

    private fun togglePauseAction(): Notification.Action {
        val paused = state.status == STATUS_PAUSED
        return Notification.Action.Builder(
            if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause,
            if (paused) "Riprendi" else "Pausa",
            servicePendingIntent(if (paused) ACTION_RESUME else ACTION_PAUSE, 20)
        ).build()
    }

    private fun nextAction(): Notification.Action =
        Notification.Action.Builder(
            android.R.drawable.ic_media_next,
            if (state.currentStep()?.isTimed == true) "Skip" else "Completato",
            servicePendingIntent(ACTION_NEXT, 21)
        ).build()

    private fun stopAction(): Notification.Action =
        Notification.Action.Builder(
            android.R.drawable.ic_menu_close_clear_cancel,
            "Stop",
            servicePendingIntent(ACTION_STOP, 22)
        ).build()

    private fun openRunnerIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("workoutRunId", state.runId)
        }
        return PendingIntent.getActivity(
            this,
            100 + state.runId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "LifePlanner Workout",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            enableVibration(true)
            vibrationPattern = VIBRATION_PATTERN
        }
        manager.createNotificationChannel(channel)
    }

    private fun vibrateForStepCompletion() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = manager.defaultVibrator
                if (vibrator.hasVibrator()) {
                    vibrator.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, -1))
                }
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (!vibrator.hasVibrator()) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(VIBRATION_PATTERN, -1)
                }
            }
        } catch (_: RuntimeException) {
            // Some devices block vibration in background modes; the timer must keep running.
        }
    }

    private fun scheduleTick() {
        handler.removeCallbacks(tickRunnable)
        handler.postDelayed(tickRunnable, 1000)
    }

    private fun persistState() {
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_STATE, state.toJson().toString())
            .apply()
    }

    private fun restoreState() {
        readStateObject(this)?.let {
            state = it
            if (state.active && !state.finished) {
                startForegroundNotification()
                scheduleTick()
            }
        }
    }

    private fun sendEvent(type: String) {
        EventBridge.emit(mapOf("type" to type, "state" to state.toFlutterMap()))
    }

    private fun formatDuration(seconds: Int): String {
        val safe = max(0, seconds)
        val minutes = safe / 60
        val secs = safe % 60
        return "%02d:%02d".format(minutes, secs)
    }

    companion object {
        private const val CHANNEL_ID = "lifeplanner_workout_foreground"
        private const val NOTIFICATION_ID = 7107
        private const val PREFERENCES_NAME = "lifeplanner_workout_foreground"
        private const val KEY_STATE = "state"
        private const val EXTRA_PAYLOAD = "payload"
        private val VIBRATION_PATTERN = longArrayOf(0, 180, 80, 180)

        private const val STATUS_IN_PROGRESS = "IN_PROGRESS"
        private const val STATUS_PAUSED = "PAUSED"
        private const val STATUS_COMPLETED = "COMPLETED"
        private const val STATUS_CANCELLED = "CANCELLED"

        const val ACTION_START = "lifeplanner.workout.action.START"
        const val ACTION_UPDATE = "lifeplanner.workout.action.UPDATE"
        const val ACTION_PAUSE = "lifeplanner.workout.action.PAUSE"
        const val ACTION_RESUME = "lifeplanner.workout.action.RESUME"
        const val ACTION_NEXT = "lifeplanner.workout.action.NEXT"
        const val ACTION_SKIP = "lifeplanner.workout.action.SKIP"
        const val ACTION_PREVIOUS = "lifeplanner.workout.action.PREVIOUS"
        const val ACTION_STOP = "lifeplanner.workout.action.STOP"

        fun command(context: Context, action: String, payload: String? = null) {
            val intent = Intent(context, WorkoutForegroundService::class.java).apply {
                this.action = action
                if (payload != null) putExtra(EXTRA_PAYLOAD, payload)
            }
            if (action == ACTION_START || action == ACTION_UPDATE) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } else {
                context.startService(intent)
            }
        }

        fun readFlutterState(context: Context): Map<String, Any?>? =
            readStateObject(context)?.toFlutterMap()

        private fun readStateObject(context: Context): WorkoutState? {
            val raw = context
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(KEY_STATE, null)
                ?: return null
            return try {
                WorkoutState.fromJson(JSONObject(raw))
            } catch (_: RuntimeException) {
                null
            }
        }
    }
}

object EventBridge {
    var sink: ((Map<String, Any?>) -> Unit)? = null

    fun emit(event: Map<String, Any?>) {
        Handler(Looper.getMainLooper()).post {
            sink?.invoke(event)
        }
    }
}

private data class WorkoutState(
    var runId: Int = 0,
    var currentStepIndex: Int = 0,
    var elapsedSeconds: Int = 0,
    var remainingTime: Int = 0,
    var status: String = "IN_PROGRESS",
    var active: Boolean = false,
    var finished: Boolean = false,
    var lastTickAt: Long = SystemClock.elapsedRealtime(),
    var sequence: List<WorkoutStep> = emptyList()
) {
    fun currentStep(): WorkoutStep? = sequence.getOrNull(currentStepIndex)

    fun toJson(): JSONObject = JSONObject()
        .put("runId", runId)
        .put("currentStepIndex", currentStepIndex)
        .put("elapsedSeconds", elapsedSeconds)
        .put("remainingTime", remainingTime)
        .put("status", status)
        .put("active", active)
        .put("finished", finished)
        .put("lastTickAt", lastTickAt)
        .put("sequence", JSONArray(sequence.map { it.toJson() }))

    fun toFlutterMap(): Map<String, Any?> = mapOf(
        "runId" to runId,
        "currentStepIndex" to currentStepIndex,
        "elapsedSeconds" to elapsedSeconds,
        "remainingTime" to remainingTime,
        "status" to status,
        "active" to active,
        "finished" to finished
    )

    companion object {
        fun fromJson(json: JSONObject): WorkoutState {
            val sequenceJson = json.optJSONArray("sequence") ?: JSONArray()
            val steps = mutableListOf<WorkoutStep>()
            for (index in 0 until sequenceJson.length()) {
                val step = sequenceJson.optJSONObject(index) ?: continue
                steps.add(WorkoutStep.fromJson(step))
            }
            val currentIndex = json.optInt("currentStepIndex", 0).coerceIn(
                0,
                max(0, steps.size - 1)
            )
            return WorkoutState(
                runId = json.optInt("runId", 0),
                currentStepIndex = currentIndex,
                elapsedSeconds = json.optInt("elapsedSeconds", 0),
                remainingTime = json.optInt("remainingTime", 0),
                status = json.optString("status", "IN_PROGRESS"),
                active = json.optBoolean("active", true),
                finished = json.optBoolean("finished", false),
                lastTickAt = json.optLong("lastTickAt", SystemClock.elapsedRealtime()),
                sequence = steps
            )
        }
    }
}

private data class WorkoutStep(
    val sequenceKey: String,
    val name: String,
    val stepType: String,
    val measurementType: String,
    val durationSeconds: Int?,
    val reps: Int?,
    val sortOrder: Int,
    val blockTitle: String?,
    val lap: Int,
    val totalLaps: Int
) {
    val isTimed: Boolean get() = measurementType == "TIME"
    val isBreak: Boolean get() = stepType == "BREAK"

    fun label(): String = if (isBreak) "Recupero" else name

    fun displayText(): String = when {
        isTimed -> "${label()} - ${durationSeconds ?: 0}s"
        reps != null -> "$name - x$reps"
        else -> name
    }

    fun toJson(): JSONObject = JSONObject()
        .put("sequenceKey", sequenceKey)
        .put("name", name)
        .put("stepType", stepType)
        .put("measurementType", measurementType)
        .put("durationSeconds", durationSeconds)
        .put("reps", reps)
        .put("sortOrder", sortOrder)
        .put("blockTitle", blockTitle)
        .put("lap", lap)
        .put("totalLaps", totalLaps)

    companion object {
        fun fromJson(json: JSONObject): WorkoutStep = WorkoutStep(
            sequenceKey = json.optString("sequenceKey"),
            name = json.optString("name", "Step"),
            stepType = json.optString("stepType", "ACTIVE"),
            measurementType = json.optString("measurementType", "REPS"),
            durationSeconds = json.optionalInt("durationSeconds"),
            reps = json.optionalInt("reps"),
            sortOrder = json.optInt("sortOrder", 0),
            blockTitle = json.optString("blockTitle").takeIf { it.isNotBlank() },
            lap = json.optInt("lap", 1),
            totalLaps = json.optInt("totalLaps", 1)
        )
    }
}

private fun JSONObject.optionalInt(key: String): Int? =
    if (has(key) && !isNull(key)) optInt(key) else null
