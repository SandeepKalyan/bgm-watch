import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Status screen for the test: clip name, playback state, position, volume,
// and the last error if there was one.
class BgmView extends WatchUi.View {

    private var _player as BgmPlayer;

    function initialize(player as BgmPlayer) {
        View.initialize();
        _player = player;
    }

    function onUpdate(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 22 / 100, Graphics.FONT_TINY, "Dude - emotional", center);

        var playing = _player.getStateText().equals("PLAYING");
        dc.setColor(playing ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 42 / 100, Graphics.FONT_MEDIUM, _player.getStateText(), center);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 58 / 100, Graphics.FONT_TINY,
            _player.getPositionSeconds() + " s   vol " + _player.getVolume(), center);

        var message = _player.getMessage();
        if (message.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 72 / 100, Graphics.FONT_XTINY, message, center);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 72 / 100, Graphics.FONT_XTINY, "START play/stop", center);
            dc.drawText(cx, h * 82 / 100, Graphics.FONT_XTINY, "UP/DOWN volume", center);
        }
    }
}
