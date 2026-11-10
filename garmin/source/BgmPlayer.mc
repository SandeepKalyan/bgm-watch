import Toybox.Application;
import Toybox.Audio;
import Toybox.Audio.Output;
import Toybox.Lang;
import Toybox.WatchUi;

// Plays one clip at a time through Toybox.Audio.Output.
// Every failure is kept as text so the player screen can show it: a
// sideloaded app on a real watch has no console.
class BgmPlayer {

    private const VOLUME_STEP = 10;
    private const VOLUME_KEY = "volume";

    private var _available as Boolean = false;
    private var _clip as Clip?;
    private var _source as AudioResource?;
    private var _volume as Number = 100;
    private var _message as String = "";

    function initialize() {
        var saved = Application.Storage.getValue(VOLUME_KEY);
        if (saved instanceof Number && saved >= 0 && saved <= 100) {
            _volume = saved;
        }

        // Older firmware has no Toybox.Audio at all. Touching it would crash.
        if (!(Toybox has :Audio)) {
            _message = "No Audio API";
            return;
        }
        try {
            Output.registerStateChangeHandler(method(:onStateChange));
            Output.setVolume(_volume);
            _available = true;
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
    }

    // Start a clip from the top.
    function play(clip as Clip) as Void {
        // Keep only one clip in memory: drop the old one before loading.
        if (_clip != clip) {
            _source = null;
        }
        _clip = clip;
        if (!_available) {
            return;
        }
        _message = "";
        try {
            var source = _source;
            if (source == null) {
                source = Application.loadResource(clip.resource) as AudioResource;
                _source = source;
            }
            Output.play(source, 0);
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
        WatchUi.requestUpdate();
    }

    // Tap or START: stop if playing, otherwise play the current clip again.
    function toggle() as Void {
        var clip = _clip;
        if (clip == null) {
            return;
        }
        if (isPlaying()) {
            stop();
        } else {
            play(clip);
        }
    }

    function stop() as Void {
        if (!_available) {
            return;
        }
        try {
            Output.stop();
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
        WatchUi.requestUpdate();
    }

    function changeVolume(up as Boolean) as Void {
        var volume = _volume + (up ? VOLUME_STEP : -VOLUME_STEP);
        if (volume > 100) {
            volume = 100;
        } else if (volume < 0) {
            volume = 0;
        }
        _volume = volume;
        try {
            // Throws when the watch's app storage is full. Losing the saved
            // volume is acceptable; crashing the app is not.
            Application.Storage.setValue(VOLUME_KEY, volume);
        } catch (e instanceof Lang.Exception) {
        }
        if (_available) {
            try {
                Output.setVolume(volume);
            } catch (e instanceof Lang.Exception) {
                _message = describe(e);
            }
        }
        WatchUi.requestUpdate();
    }

    function close() as Void {
        if (!_available) {
            return;
        }
        // Separate tries: a failing stop() must not leave the handler set.
        try {
            Output.stop();
        } catch (e instanceof Lang.Exception) {
        }
        try {
            Output.registerStateChangeHandler(null);
        } catch (e instanceof Lang.Exception) {
        }
    }

    function onStateChange(state as Output.PlaybackState) as Void {
        if (state == Output.PLAYBACK_ERROR) {
            _message = "Play error " + Output.getError();
        }
        WatchUi.requestUpdate();
    }

    // Asks the system each time instead of caching the callback's value: the
    // docs do not promise a callback when a clip reaches its end on its own.
    function isPlaying() as Boolean {
        if (!_available) {
            return false;
        }
        try {
            return Output.getState() == Output.PLAYBACK_PLAYING;
        } catch (e instanceof Lang.Exception) {
            return false;
        }
    }

    function getPositionMs() as Number {
        if (!_available) {
            return 0;
        }
        try {
            return Output.getPosition();
        } catch (e instanceof Lang.Exception) {
            return 0;
        }
    }

    function getClip() as Clip? {
        return _clip;
    }

    function getVolume() as Number {
        return _volume;
    }

    function getMessage() as String {
        return _message;
    }

    private function describe(e as Lang.Exception) as String {
        var text = e.getErrorMessage();
        return (text != null) ? text : "Unknown error";
    }
}
