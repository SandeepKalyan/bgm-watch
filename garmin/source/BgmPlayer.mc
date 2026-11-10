import Toybox.Application;
import Toybox.Audio;
import Toybox.Audio.Output;
import Toybox.Lang;
import Toybox.WatchUi;

// Plays the one bundled clip through Toybox.Audio.Output.
// Every failure is kept as text so the view can show it: a sideloaded app
// on a real watch has no console.
class BgmPlayer {

    private const VOLUME_STEP = 10;

    private var _available as Boolean = false;
    private var _source as AudioResource?;
    private var _state as Output.PlaybackState = Output.PLAYBACK_STOPPED;
    private var _positionMs as Number = 0;
    private var _volume as Number = 100;
    private var _message as String = "";

    function initialize() {
        // Older firmware has no Toybox.Audio at all. Touching it would crash.
        if (!(Toybox has :Audio)) {
            _message = "No Audio API";
            return;
        }
        try {
            Output.registerStateChangeHandler(method(:onStateChange));
            Output.registerPeriodicUpdateHandler(500, method(:onPosition));
            Output.setVolume(_volume);
            _state = Output.getState();
            _available = true;
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
    }

    // START button: play from the top, or stop if already playing.
    function toggle() as Void {
        if (!_available) {
            return;
        }
        try {
            // Ask the system, not the cached copy: the docs do not promise a
            // state callback when a clip reaches its end on its own.
            _state = Output.getState();
            if (_state == Output.PLAYBACK_PLAYING) {
                Output.stop();
            } else {
                var source = _source;
                if (source == null) {
                    source = Application.loadResource(Rez.Audios.dude_emotional) as AudioResource;
                    _source = source;
                }
                _message = "";
                _positionMs = 0;
                Output.play(source, 0);
            }
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
        WatchUi.requestUpdate();
    }

    function changeVolume(up as Boolean) as Void {
        if (!_available) {
            return;
        }
        var volume = _volume + (up ? VOLUME_STEP : -VOLUME_STEP);
        if (volume > 100) {
            volume = 100;
        } else if (volume < 0) {
            volume = 0;
        }
        try {
            Output.setVolume(volume);
            _volume = volume;
        } catch (e instanceof Lang.Exception) {
            _message = describe(e);
        }
        WatchUi.requestUpdate();
    }

    function close() as Void {
        if (!_available) {
            return;
        }
        // Separate tries: a failing stop() must not leave the handlers set.
        try {
            Output.stop();
        } catch (e instanceof Lang.Exception) {
        }
        try {
            Output.registerStateChangeHandler(null);
            Output.registerPeriodicUpdateHandler(500, null);
        } catch (e instanceof Lang.Exception) {
        }
    }

    function onStateChange(state as Output.PlaybackState) as Void {
        _state = state;
        if (state == Output.PLAYBACK_ERROR) {
            _message = "Play error " + Output.getError();
        } else if (state == Output.PLAYBACK_STOPPED) {
            _positionMs = 0;
        }
        WatchUi.requestUpdate();
    }

    function onPosition(position as Number) as Void {
        _positionMs = position;
        WatchUi.requestUpdate();
    }

    function getStateText() as String {
        if (!_available) {
            return "UNAVAILABLE";
        }
        try {
            _state = Output.getState();
        } catch (e instanceof Lang.Exception) {
        }
        switch (_state) {
            case Output.PLAYBACK_PLAYING:
                return "PLAYING";
            case Output.PLAYBACK_PAUSED:
                return "PAUSED";
            case Output.PLAYBACK_ERROR:
                return "ERROR";
            default:
                return "STOPPED";
        }
    }

    function getPositionSeconds() as Number {
        return _positionMs / 1000;
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
