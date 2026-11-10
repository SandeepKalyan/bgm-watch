import Toybox.Lang;
import Toybox.WatchUi;

// Mood map input.
//   Tap a bubble            open its clip list
//   UP / DOWN, or a swipe   move the focus from bubble to bubble
//   START                   open the bubble in focus
//   BACK                    left to the system, which exits the app
//
// Taps and START are read through the raw handlers (onTap, onKey) rather than
// onSelect, because onSelect cannot tell where the screen was touched.
class MoodMapDelegate extends WatchUi.BehaviorDelegate {

    private var _view as MoodMapView;
    private var _emotions as Array<Emotion>;
    private var _clips as Array<Clip>;
    private var _player as BgmPlayer;

    function initialize(view as MoodMapView, emotions as Array<Emotion>, clips as Array<Clip>, player as BgmPlayer) {
        BehaviorDelegate.initialize();
        _view = view;
        _emotions = emotions;
        _clips = clips;
        _player = player;
    }

    function onNextPage() as Boolean {
        _view.moveFocus(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.moveFocus(-1);
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            open(_view.getFocus());
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        var node = _view.hitTest(point[0], point[1]);
        if (node >= 0) {
            _view.setFocus(node);
            open(node);
        }
        return true;
    }

    // Opens the clip list of one emotion, or of every clip for ALL.
    private function open(node as Number) as Void {
        var all = (node >= _emotions.size());
        var clips = [] as Array<Clip>;
        for (var i = 0; i < _clips.size(); i++) {
            if (all || _clips[i].emotion == node) {
                clips.add(_clips[i]);
            }
        }
        if (clips.size() > 0) {
            var title = all ? "ALL" : _emotions[node].label;
            WatchUi.pushView(ClipList.build(title, clips), new ClipMenuDelegate(clips, _player), WatchUi.SLIDE_LEFT);
        }
    }
}
