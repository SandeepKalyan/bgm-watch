import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Player screen: clip name, a play/stop symbol, a progress ring around the
// edge, the volume, and the last error if there was one.
class PlayerView extends WatchUi.View {

    private const RING_WIDTH = 10;
    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    private var _player as BgmPlayer;
    private var _timer as Timer.Timer?;

    function initialize(player as BgmPlayer) {
        View.initialize();
        _player = player;
    }

    // Redraw twice a second while visible, so the ring moves and the screen
    // notices when a clip ends on its own.
    function onShow() as Void {
        onHide(); // never leave an earlier timer running
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 500, true);
        _timer = timer;
    }

    function onHide() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var clip = _player.getClip();
        var playing = _player.isPlaying();
        var positionMs = playing ? _player.getPositionMs() : 0;
        var durationMs = (clip != null) ? clip.durationMs : 0;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawRing(dc, cx, cy, playing, positionMs, durationMs);

        if (clip != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 17 / 100, Graphics.FONT_XTINY, clip.subtitle, CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 28 / 100, pickFont(dc, clip.title, w * 78 / 100), clip.title, CENTER);
        }

        drawSymbol(dc, cx, cy, w * 13 / 100, playing);

        var message = _player.getMessage();
        if (message.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 70 / 100, Graphics.FONT_XTINY, message, CENTER);
        } else {
            var total = (durationMs + 500) / 1000;
            var text = playing
                ? Lang.format("$1$ / $2$ s", [positionMs / 1000, total])
                : Lang.format("$1$ s", [total]);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 70 / 100, Graphics.FONT_XTINY, text, CENTER);
        }

        drawVolume(dc, cx, w, h, _player.getVolume());
    }

    // Grey ring, with a green arc growing clockwise from twelve o'clock.
    private function drawRing(dc as Dc, cx as Number, cy as Number, playing as Boolean,
            positionMs as Number, durationMs as Number) as Void {
        var radius = cx - RING_WIDTH / 2 - 2;
        dc.setPenWidth(RING_WIDTH);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        if (playing && durationMs > 0) {
            var degrees = (360.0 * positionMs / durationMs).toNumber();
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            if (degrees >= 360) {
                dc.drawCircle(cx, cy, radius);
            } else if (degrees > 0) {
                // drawArc measures counter-clockwise from three o'clock, so
                // twelve o'clock is 90. Equal start and end angles would draw
                // a whole circle; the two checks above rule that out.
                var end = 90 - degrees;
                if (end < 0) {
                    end += 360;
                }
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, end);
            }
        }
        dc.setPenWidth(1);
    }

    // Shows what a tap will do: a square (stop) while playing, a triangle
    // (play) otherwise.
    private function drawSymbol(dc as Dc, cx as Number, cy as Number, size as Number, playing as Boolean) as Void {
        if (playing) {
            var half = size * 65 / 100;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - half, cy - half, half * 2, half * 2);
        } else {
            // Shifted right a little: a triangle centred on its bounding box
            // looks off-centre.
            var left = cx - size * 55 / 100;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[left, cy - size], [left, cy + size], [cx + size, cy]]);
        }
    }

    private function drawVolume(dc as Dc, cx as Number, w as Number, h as Number, volume as Number) as Void {
        var barWidth = w * 36 / 100;
        var barHeight = 8;
        var x = cx - barWidth / 2;
        var y = h * 86 / 100;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 79 / 100, Graphics.FONT_XTINY, "VOL " + volume.toString(), CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, barWidth, barHeight, barHeight / 2);
        var filled = barWidth * volume / 100;
        if (filled > 0) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, filled, barHeight, barHeight / 2);
        }
    }

    // Largest of three fonts in which the text fits the given width.
    private function pickFont(dc as Dc, text as String, maxWidth as Number) as Graphics.FontDefinition {
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontDefinition>;
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                return fonts[i];
            }
        }
        return Graphics.FONT_XTINY;
    }
}
