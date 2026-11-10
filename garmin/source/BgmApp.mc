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

    // The home screen is the clip list. Choosing a clip plays it at once.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var player = new BgmPlayer();
        _player = player;

        var clips = ClipLibrary.getClips();
        var menu = new WatchUi.Menu2({:title => "BGM"});
        for (var i = 0; i < clips.size(); i++) {
            var clip = clips[i];
            menu.addItem(new WatchUi.MenuItem(clip.title, clip.getSubLabel(), i, null));
        }
        return [menu, new ClipMenuDelegate(clips, player)];
    }
}
