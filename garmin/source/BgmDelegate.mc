import Toybox.Lang;
import Toybox.WatchUi;

// START (or screen tap) toggles the clip. UP/DOWN change volume.
// BACK is left to the system, which exits the app.
class BgmDelegate extends WatchUi.BehaviorDelegate {

    private var _player as BgmPlayer;

    function initialize(player as BgmPlayer) {
        BehaviorDelegate.initialize();
        _player = player;
    }

    function onSelect() as Boolean {
        _player.toggle();
        return true;
    }

    function onPreviousPage() as Boolean {
        _player.changeVolume(true);
        return true;
    }

    function onNextPage() as Boolean {
        _player.changeVolume(false);
        return true;
    }
}
