import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

// Player screen in the HUD style: a ring of blocks that fills as the clip
// plays, the clip and film names, pulse bars while playing (a play symbol
// when stopped), the time, the volume as a row of blocks, and the last error
// if there was one.
class PlayerView extends WatchUi.View {

    private const PROGRESS_BLOCKS = 40;
    private const VOLUME_BLOCKS = 10;
    private const PULSE_BARS = 15;
    private const REFRESH_MS = 250;

    private var _player as BgmPlayer;
    private var _timer as Timer.Timer?;

    function initialize(player as BgmPlayer) {
        View.initialize();
        _player = player;
    }

    // Redraw four times a second while visible, so the gauges move and the
    // screen notices when a clip ends on its own.
    function onShow() as Void {
        onHide(); // never leave an earlier timer running
        var timer = new Timer.Timer();
        timer.start(method(:onTick), REFRESH_MS, true);
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

        Hud.begin(dc);
        Hud.drawTickRing(dc);

        var lit = 0;
        if (playing && durationMs > 0) {
            lit = (PROGRESS_BLOCKS.toFloat() * positionMs / durationMs).toNumber() + 1;
            if (lit > PROGRESS_BLOCKS) {
                lit = PROGRESS_BLOCKS;
            }
        }
        Hud.drawBlockArc(dc, cx - 31, 10, PROGRESS_BLOCKS, lit);

        if (clip != null) {
            dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 21 / 100, Hud.font(24), clip.subtitle.toUpper(), Hud.CENTER);
            dc.setColor(Hud.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 31 / 100, Hud.fitFont(dc, clip.title, w * 70 / 100, [38, 33, 28, 24]),
                clip.title, Hud.CENTER);
        }

        if (playing) {
            drawPulse(dc, cx, cy + h * 2 / 100);
        } else {
            drawPlaySymbol(dc, cx, cy + h * 2 / 100, w * 10 / 100);
        }

        var message = _player.getMessage();
        if (message.length() > 0) {
            dc.setColor(Hud.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 69 / 100, Hud.font(24), message, Hud.CENTER);
        } else {
            var total = (durationMs + 500) / 1000;
            var text = playing
                ? Lang.format("$1$ / $2$ S", [(positionMs / 1000).format("%02d"), total])
                : Lang.format("$1$ S", [total]);
            dc.setColor(Hud.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 69 / 100, Hud.font(28), text, Hud.CENTER);
        }

        Hud.drawBlockBar(dc, cx, h * 79 / 100, VOLUME_BLOCKS, (_player.getVolume() + 5) / 10);
    }

    // Bars that jump while a clip plays, tallest in the middle. The heights
    // are random: the watch does not report audio levels.
    private function drawPulse(dc as Dc, cx as Number, cy as Number) as Void {
        var barWidth = 10;
        var gap = 8;
        var left = cx - (PULSE_BARS * barWidth + (PULSE_BARS - 1) * gap) / 2;
        dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < PULSE_BARS; i++) {
            var fromMiddle = (i - PULSE_BARS / 2).abs();
            var limit = 46 - fromMiddle * 5;
            var half = 4 + (Math.rand() & 0x7FFFFFFF) % limit;
            dc.fillRectangle(left + i * (barWidth + gap), cy - half, barWidth, half * 2);
        }
    }

    // Shown while stopped: a tap plays the clip again.
    private function drawPlaySymbol(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        // Shifted right a little: a triangle centred on its bounding box
        // looks off-centre.
        var left = cx - size * 55 / 100;
        dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[left, cy - size], [left, cy + size], [cx + size, cy]]);
    }
}
