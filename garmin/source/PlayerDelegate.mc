import Toybox.Lang;
import Toybox.WatchUi;

// Player screen input.
//   Tap or START            play / stop
//   Swipe up or UP key      louder
//   Swipe down or DOWN key  quieter
//   BACK or swipe right     stop and return to the list
//
// Volume uses the raw key and swipe handlers on purpose. The page behaviours
// (onNextPage / onPreviousPage) fire for keys and for swipes, with a swipe up
// meaning "next page" like the DOWN key. That would make a swipe up turn the
// volume down, so those behaviours are left unhandled.
class PlayerDelegate extends WatchUi.BehaviorDelegate {

    private var _player as BgmPlayer;

    function initialize(player as BgmPlayer) {
        BehaviorDelegate.initialize();
        _player = player;
    }

    function onSelect() as Boolean {
        _player.toggle();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            _player.changeVolume(true);
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _player.changeVolume(false);
            return true;
        }
        return false;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_UP) {
            _player.changeVolume(true);
            return true;
        }
        if (direction == WatchUi.SWIPE_DOWN) {
            _player.changeVolume(false);
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        _player.stop();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
