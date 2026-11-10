package com.bgmwatch.wear

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class MainActivity : Activity() {

    private enum class State { STOPPED, PLAYING, ERROR }

    private lateinit var audio: AudioManager
    private lateinit var stateView: TextView
    private lateinit var elapsedView: TextView
    private lateinit var volumeView: TextView
    private lateinit var messageView: TextView
    private lateinit var button: Button

    private var player: MediaPlayer? = null
    private var state = State.STOPPED
    private var message = ""
    private var rotaryAccum = 0f
    private val ui = Handler(Looper.getMainLooper())

    private val tick = object : Runnable {
        override fun run() {
            render()
            if (state == State.PLAYING) ui.postDelayed(this, 250)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audio = getSystemService(AUDIO_SERVICE) as AudioManager
        volumeControlStream = AudioManager.STREAM_MUSIC
        setContentView(buildUi())
        render()
    }

    private fun label(sizeSp: Float, bold: Boolean = false) = TextView(this).apply {
        setTextColor(Color.WHITE)
        textSize = sizeSp
        gravity = Gravity.CENTER
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun buildUi(): View {
        val density = resources.displayMetrics.density
        val pad = (density * 20).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(pad, pad / 2, pad, pad / 2)
        }
        val wrap = ViewGroup.LayoutParams.WRAP_CONTENT
        root.addView(label(13f, true).apply { text = "Dude - emotional" }, LinearLayout.LayoutParams(-1, wrap))
        stateView = label(15f, true).also { root.addView(it, LinearLayout.LayoutParams(-1, wrap)) }
        elapsedView = label(12f).also { root.addView(it, LinearLayout.LayoutParams(-1, wrap)) }
        button = Button(this).apply {
            textSize = 18f
            setOnClickListener { toggle() }
        }
        root.addView(button, LinearLayout.LayoutParams(-1, (density * 56).toInt()))
        volumeView = label(12f).also { root.addView(it, LinearLayout.LayoutParams(-1, wrap)) }
        messageView = label(11f).apply { setTextColor(Color.parseColor("#FF8A80")) }
            .also { root.addView(it, LinearLayout.LayoutParams(-1, wrap)) }
        return root
    }

    private fun render() {
        stateView.text = state.name
        stateView.setTextColor(
            when (state) {
                State.PLAYING -> Color.parseColor("#69F0AE")
                State.ERROR -> Color.parseColor("#FF5252")
                State.STOPPED -> Color.WHITE
            }
        )
        val ms = if (state == State.PLAYING) (player?.currentPosition ?: 0) else 0
        elapsedView.text = "${ms / 1000} s"
        button.text = if (state == State.PLAYING) "STOP" else "PLAY"
        val cur = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        volumeView.text = "Vol $cur / $max"
        messageView.text = message
    }

    private fun speaker(): AudioDeviceInfo? =
        audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }

    private fun toggle() {
        if (state == State.PLAYING) stop() else play()
    }

    private fun play() {
        release()
        message = ""
        val spk = speaker()
        if (spk == null) {
            fail("No speaker on this watch")
            return
        }
        try {
            val mp = MediaPlayer()
            player = mp
            val afd = resources.openRawResourceFd(R.raw.dude_emotional)
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            if (!mp.setPreferredDevice(spk)) {
                fail("Could not route audio to the watch speaker")
                return
            }
            mp.setOnCompletionListener { stop() }
            mp.setOnErrorListener { _, what, extra ->
                fail("Playback error ($what, $extra)")
                true
            }
            mp.setOnPreparedListener {
                it.start()
                state = State.PLAYING
                ui.removeCallbacks(tick)
                ui.post(tick)
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            fail("Error: ${e.javaClass.simpleName}: ${e.message}")
        }
    }

    private fun stop() {
        release()
        state = State.STOPPED
        render()
    }

    private fun fail(msg: String) {
        release()
        state = State.ERROR
        message = msg
        render()
    }

    private fun release() {
        ui.removeCallbacks(tick)
        player?.let {
            it.setOnCompletionListener(null)
            it.setOnErrorListener(null)
            try { it.release() } catch (_: Exception) {}
        }
        player = null
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)
        ) {
            // AXIS_SCROLL is negative for clockwise on Wear, so negate: clockwise = louder.
            rotaryAccum += -event.getAxisValue(MotionEvent.AXIS_SCROLL)
            if (abs(rotaryAccum) >= 0.5f) {
                val dir = if (rotaryAccum > 0) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                rotaryAccum = 0f
                audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, dir, 0)
                render()
            }
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    override fun onResume() {
        super.onResume()
        // Rotary events are only delivered to a focused view.
        window.decorView.requestFocus()
        render()
    }

    override fun onStop() {
        stop()
        super.onStop()
    }

    override fun onDestroy() {
        release()
        super.onDestroy()
    }
}
