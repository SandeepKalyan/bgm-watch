import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BgmApp extends Application.AppBase {

    private var _player as BgmPlayer?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    // Audio only plays while the app is in the foreground, so stop on exit.
    function onStop(state as Dictionary?) as Void {
        var player = _player;
        if (player != null) {
            player.close();
        }
    }

    // The home screen is the mood map: pick an emotion, then a clip.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var player = new BgmPlayer();
        _player = player;

        var emotions = ClipLibrary.getEmotions();
        var clips = ClipLibrary.getClips();
        var map = new MoodMapView(emotions, clips);
        return [map, new MoodMapDelegate(map, emotions, clips, player)];
    }
}
