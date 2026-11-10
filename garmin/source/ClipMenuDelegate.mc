import Toybox.Lang;
import Toybox.WatchUi;

// Clip list input. Tapping a row (or pressing START on it) starts the clip
// and opens the player screen. BACK is left to the system, which returns to
// the mood map.
class ClipMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _clips as Array<Clip>;
    private var _player as BgmPlayer;

    function initialize(clips as Array<Clip>, player as BgmPlayer) {
        Menu2InputDelegate.initialize();
        _clips = clips;
        _player = player;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var index = item.getId();
        if (index instanceof Number && index >= 0 && index < _clips.size()) {
            // Sound first, screen second: the clip should start the instant
            // the row is touched.
            _player.play(_clips[index]);
            WatchUi.pushView(new PlayerView(_player), new PlayerDelegate(_player), WatchUi.SLIDE_LEFT);
        }
    }
}
