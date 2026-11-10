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

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var player = new BgmPlayer();
        _player = player;
        return [new BgmView(player), new BgmDelegate(player)];
    }
}
